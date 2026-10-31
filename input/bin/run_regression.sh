#!/usr/bin/env bash

# Determine directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INPUT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ROOT_DIR="$(cd "${INPUT_DIR}/.." && pwd)"

# Parse optional arguments
TCPTRACE=""
MODE="quick"

for arg in "$@"; do
    case "$arg" in
        --mode=*)
            MODE="${arg#*=}"
            ;;
        --full)
            MODE="full"
            ;;
        --quick)
            MODE="quick"
            ;;
        -*)
            echo "Unknown option: $arg" >&2
            echo "Usage: $0 [options] [path-to-tcptrace]" >&2
            echo "Options: --quick (default), --full" >&2
            exit 1
            ;;
        *)
            TCPTRACE="$arg"
            ;;
    esac
done

if [ -z "$TCPTRACE" ]; then
    if [ -x "${ROOT_DIR}/tcptrace" ]; then
        TCPTRACE="${ROOT_DIR}/tcptrace"
    elif [ -x "${ROOT_DIR}/build/tcptrace" ]; then
        TCPTRACE="${ROOT_DIR}/build/tcptrace"
    elif command -v tcptrace >/dev/null 2>&1; then
        TCPTRACE="$(command -v tcptrace)"
    else
        echo "Error: tcptrace binary not found. Specify path as argument: $0 [options] <path-to-tcptrace>" >&2
        exit 1
    fi
fi

# Ensure absolute path for TCPTRACE
TCPTRACE_DIR="$(cd "$(dirname "$TCPTRACE")" && pwd)"
TCPTRACE="${TCPTRACE_DIR}/$(basename "$TCPTRACE")"

echo "=== Running tcptrace Regression Suite (${MODE} mode) ==="
echo "Using binary: ${TCPTRACE}"

# Set deterministic environment
if [ -f /usr/share/zoneinfo/America/New_York ]; then
    export TZ=America/New_York
elif [ -f /usr/share/zoneinfo/EST5EDT ]; then
    export TZ=EST5EDT
else
    export TZ="${TZ:-America/New_York}"
fi
export LC_ALL=C

cd "${INPUT_DIR}"

OUTDIR="OUTPUT_TEST"
rm -rf "${OUTDIR}" *.xpl DIFFS
mkdir -p "${OUTDIR}"

# Detect supported file formats
"${TCPTRACE}" -hconfig 2>&1 | awk '/^\t[a-zA-Z]+/ { gsub(/^\t([a-zA-Z]+).*/,$1); print }' | grep -v Suffix > file_formats.tmp

SUPPORTED_FILES=""
while read -r TYPE; do
    if [ -f "${TYPE}_files" ]; then
        for f in $(cat "${TYPE}_files"); do
            SUPPORTED_FILES="$SUPPORTED_FILES $f"
        done
    fi
done < file_formats.tmp
rm -f file_formats.tmp

FAILED=0
TOTAL=0
PASSED=0

# Filter function to strip non-deterministic lines
filter_output() {
    grep -v "elapsed wallclock" | grep -v "Ostermann's tcptrace -- version" | grep -v "Broken pipe" || true
}

for FILE in $SUPPORTED_FILES; do
    if [ ! -f "$FILE" ]; then
        continue
    fi
    TOTAL=$((TOTAL + 1))
    printf "Testing %-28s ... " "$FILE"

    FILE_FAIL=0

    # 1. Short output test
    if [ -f "OUTPUTbench/${FILE}.short" ]; then
        "${TCPTRACE}" +t -nr "${FILE}" 2>&1 | filter_output > "${OUTDIR}/${FILE}.short"
        if ! diff -u "OUTPUTbench/${FILE}.short" "${OUTDIR}/${FILE}.short" > "${OUTDIR}/${FILE}.short.diff" 2>&1; then
            FILE_FAIL=1
            echo ""
            echo "  [FAIL] ${FILE}.short mismatch (first 20 lines):"
            head -n 20 "${OUTDIR}/${FILE}.short.diff"
        fi
    fi

    # 2. Packets test
    if [ -f "OUTPUTbench/${FILE}.packets" ]; then
        "${TCPTRACE}" +t -pn -E100 --checksum "${FILE}" 2> "${OUTDIR}/${FILE}.packets.err" | filter_output > "${OUTDIR}/${FILE}.packets"
        if ! diff -u "OUTPUTbench/${FILE}.packets" "${OUTDIR}/${FILE}.packets" > "${OUTDIR}/${FILE}.packets.diff" 2>&1; then
            FILE_FAIL=1
            echo ""
            echo "  [FAIL] ${FILE}.packets mismatch (first 20 lines):"
            head -n 20 "${OUTDIR}/${FILE}.packets.diff"
            if [ -s "${OUTDIR}/${FILE}.packets.err" ]; then
                echo "  Stderr output:"
                head -n 10 "${OUTDIR}/${FILE}.packets.err"
            fi
        fi
    fi

    # 3. Full mode tests (long format and xplots)
    if [ "$MODE" = "full" ]; then
        if [ -f "OUTPUTbench/${FILE}.long" ]; then
            "${TCPTRACE}" +t -lnrW "${FILE}" 2>&1 | filter_output > "${OUTDIR}/${FILE}.long"
            if ! diff -u "OUTPUTbench/${FILE}.long" "${OUTDIR}/${FILE}.long" > "${OUTDIR}/${FILE}.long.diff" 2>&1; then
                FILE_FAIL=1
                echo ""
                echo "  [FAIL] ${FILE}.long mismatch (first 20 lines):"
                head -n 20 "${OUTDIR}/${FILE}.long.diff"
            fi
        fi

        if [ -f "OUTPUTbench/${FILE}.xplots.cksum" ]; then
            "${TCPTRACE}" +t -n -G -E1000 --output_dir=. "${FILE}" > /dev/null 2>&1
            cksum *.xpl 2>/dev/null | sed 's/[ 	][ 	]*/	/g' | LC_ALL=C sort -k3 > "${OUTDIR}/${FILE}.xplots.cksum" || true
            rm -f *.xpl
            LC_ALL=C sort -k3 "OUTPUTbench/${FILE}.xplots.cksum" > "${OUTDIR}/${FILE}.bench.cksum"
            if ! diff -u "${OUTDIR}/${FILE}.bench.cksum" "${OUTDIR}/${FILE}.xplots.cksum" > "${OUTDIR}/${FILE}.cksum.diff" 2>&1; then
                FILE_FAIL=1
                echo ""
                echo "  [FAIL] ${FILE}.cksum mismatch (first 20 lines):"
                head -n 20 "${OUTDIR}/${FILE}.cksum.diff"
            fi
        fi
    fi

    if [ "$FILE_FAIL" -eq 0 ]; then
        PASSED=$((PASSED + 1))
        echo "PASS"
    else
        FAILED=$((FAILED + 1))
        echo "FAIL"
    fi
done

echo "========================================="
echo "Results: $PASSED / $TOTAL passed"

if [ "$FAILED" -ne 0 ]; then
    echo "Failures occurred. Diffs stored in ${INPUT_DIR}/${OUTDIR}/"
    exit 1
fi

echo "All regression tests passed successfully."
exit 0
