# Implementation Plan: Codebase Modernization for `tcptrace`

Modernize the build system, ensure clean compilation on modern compilers (macOS Apple Clang and Linux GCC/Clang), upgrade to modern C standards (`<stdint.h>` / `<inttypes.h>`), automate regression testing with CTest and sanitizers, and implement multi-platform Continuous Integration.

---

## User Review Required

> [!IMPORTANT]
> - **Removal of legacy Windows/Cygwin static binaries**: The repository contains pre-compiled 32-bit Cygwin libraries in `cygwin-libs/` and old headers in `cygwin-includes/` from 2001. We will prune these dead binary artifacts as agreed during the interview.
> - **Removal of `memcpy` macro override**: In `tcptrace.h`, `#define memcpy(p1,p2,n) MemCpy(p1,p2,n)` overrides the C standard library. We will remove this macro and use standard `memcpy` from `<string.h>`, which fixes clang compilation failures and optimizes memory copies.

---

## Open Questions

None. All architectural decisions (CMake introduction, C11 standard, CTest integration, sanitizer support, and CI matrix) were resolved during the alignment interview.

---

## Proposed Changes

### Phase 1: Immediate Compilation Fixes

#### [MODIFY] `mod_traffic.c`
- Change `static int traffic_init_files(void)` to `static void traffic_init_files(void)` at line 295.
- Fix bare `return;` statements inside `traffic_init_files`.

```diff
-static int
+static void
 traffic_init_files(void)
 {
     static int created = 0;
 
     if (created)
 	return;
```

#### [MODIFY] `tcptrace.h`
- Remove the conflicting `memcpy` macro redefinition and `MemCpy` declaration.
- Ensure `USE_LLU` is active by default on standard platforms instead of obsolete `%qu`.

```diff
-#ifndef __VMS
-/* I've had problems with the memcpy function that gcc stuffs into the program
-   and alignment problems.  This should fix it! */
-void *MemCpy(void *p1, void *p2, size_t n); /* in tcptrace.c */
-#define memcpy(p1,p2,n) MemCpy(p1,p2,n)
-#endif /* __VMS */
```

#### [MODIFY] `tcptrace.c`
- Remove obsolete `MemCpy` implementation at lines 2619-2628.

#### [MODIFY] `etherpeek.c`
- Fix printf format mismatches where `%ld` is used for `tt_uint32` (change to `%u`).

---

### Phase 2: Modern Build System (CMake + Autotools Modernization)

#### [NEW] `CMakeLists.txt`
Create a clean modern CMake configuration:
- C Standard: C11 (with fallback to C99).
- Dependency detection:
  - `find_package(PCAP REQUIRED)` / `pkg_check_modules` / fallback checks for `<pcap.h>` and `-lpcap`.
  - `find_package(BISON REQUIRED)` and `find_package(FLEX REQUIRED)` to generate `filt_parser.c/.h` and `filt_scanner.c`.
  - Math library `m`.
  - Optional compression utilities (`gunzip`, `bunzip2`).
- Target definition: `tcptrace` executable with all modules (`mod_http`, `mod_traffic`, `mod_rttgraph`, `mod_collie`, `mod_slice`, `mod_realtime`).
- Target definition: `versnum` executable.
- Options:
  - `ENABLE_SANITIZERS`: enables AddressSanitizer and UndefinedBehaviorSanitizer (`-fsanitize=address,undefined`).
  - `ENABLE_WERROR`: enables `-Werror` (useful for CI).
- Installation rules: install binary to `bin/` and man page to `share/man/man1/`.

#### [NEW] `config.h.cmake.in`
- Header template for CMake `configure_file` providing feature detection macros (`HAVE_PCAP_H`, `HAVE_STDINT_H`, `HAVE_INET_PTON`, etc.).

#### [NEW] `configure.ac`
- Modernize `configure.in` to `configure.ac` using standard Autoconf 2.69+ syntax, removing obsolete macros.

---

### Phase 3: Code Modernization & Standardization

#### [MODIFY] `tcptrace.h`
- Include standard `<stdint.h>` and `<inttypes.h>`.
- Redefine core types cleanly:
  - `typedef uint32_t tt_uint32;`
  - `typedef uint16_t tt_uint16;`
  - `typedef int32_t tt_int32;`
  - `typedef int16_t tt_int16;`
  - `typedef uint64_t tt_uint64;`
  - `typedef int64_t tt_int64;`
- Replace custom `FS_ULL` definitions with standard `PRIu64` / `%llu`.

#### [DELETE] `cygwin-libs/` & `cygwin-includes/`
- Delete bundled 25-year-old binary `.a` and `.h` files:
  - `cygwin-libs/libwpcap.a`, `cygwin-libs/libpcap.a`
  - `cygwin-includes/*`

---

### Phase 4: Test & Verification Automation

#### [NEW] `input/bin/run_regression.sh`
- Modern shell script replacing and improving `input/bin/REGRESS`:
  - Locates `tcptrace` binary dynamically (build directory or PATH).
  - Runs regression suites on supported formats (`tcpdump`, `snoop`, `etherpeek`, `erf`).
  - Cleans variable lines (timestamps, banners).
  - Diffing against `input/OUTPUTbench`.
  - Exits with return code 0 on all tests passing, or return code 1 with clear diff diagnostics on mismatch.

#### [MODIFY] `CMakeLists.txt`
- Add `enable_testing()` and define `add_test(NAME regression_test COMMAND ...)` so tests execute via `ctest`.

#### [MODIFY] `Makefile.in`
- Add `check:` and `test:` targets to run the regression suite via classic `make check`.

---

### Phase 5: Multi-Platform GitHub Actions CI

#### [NEW] `.github/workflows/ci.yml`
- **Workflow Triggers**: `push` to master and `pull_request`.
- **Matrix**:
  - `ubuntu-latest` with GCC
  - `ubuntu-latest` with Clang
  - `ubuntu-latest` with Clang + ASan/UBSan
  - `macos-latest` with Apple Clang
- **Steps**:
  1. Checkout repository with depth 1.
  2. Install system packages (`libpcap-dev`, `bison`, `flex` on Ubuntu; `libpcap`, `bison`, `flex` on macOS).
  3. Configure and build via CMake:
     `cmake -B build -DCMAKE_BUILD_TYPE=Release -DENABLE_WERROR=ON`
     `cmake --build build -j`
  4. Run test suite:
     `ctest --test-dir build --output-on-failure`
  5. Verify legacy Autotools build:
     `./configure && make -j`

---

## Verification Plan

### Automated Tests
1. **Compilation Verification**:
   - `cmake -B build -DCMAKE_BUILD_TYPE=Release`
   - `cmake --build build`
   - `./build/tcptrace -v` (verify banner and version output)
2. **Regression Test Suite**:
   - `ctest --test-dir build --output-on-failure`
   - `cd input && bin/run_regression.sh ../build/tcptrace`
3. **Memory Safety & Sanitizers**:
   - `cmake -B build-asan -DENABLE_SANITIZERS=ON`
   - `cmake --build build-asan`
   - `ctest --test-dir build-asan --output-on-failure` (verifies zero memory leaks, buffer overflows, or undefined behavior across sample traces)
4. **Autotools Compatibility**:
   - `make clean && ./configure && make`
   - `./tcptrace -v`

### Manual Verification
- Run `./build/tcptrace input/6syns.dmp.gz` and verify output formats and summary stats match expectations.
- Run `./build/tcptrace -G input/bad_ack_code.dmp.gz` and verify xplot output files are generated.
