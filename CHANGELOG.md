# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [6.7.0] - 2026-10-31

### Modernization & Build System
- **CMake Support**: Added complete [`CMakeLists.txt`](CMakeLists.txt) supporting C11 standard, automated Bison/Flex parser/scanner generation with fallback, and CTest integration.
- **Dual Build Compatibility**: Maintained existing Autotools (`./configure && make`) build pipeline alongside CMake.
- **Automated Regression Harness**: Added [`input/bin/run_regression.sh`](input/bin/run_regression.sh) and wired `make test` / `make check` and `ctest` across 40 test suites.
- **GitHub Actions CI**: Added multi-platform workflow matrix ([`.github/workflows/ci.yml`](.github/workflows/ci.yml)) testing Ubuntu (GCC, Clang, ASan/UBSan) and macOS (Apple Clang).

### C Standards & Portability
- **Standard Integer Types**: Replaced custom `#if SIZEOF_...` type discovery blocks in [`tcptrace.h`](tcptrace.h) with standard `<stdint.h>` and `<inttypes.h>` (`uint32_t`, `uint64_t`, `int32_t`, `int16_t`, `PRIu64`, `PRId64`).
- **Standard Library Cleanup**: Removed conflicting `#define memcpy` macro override in [`tcptrace.h`](tcptrace.h) and obsolete `MemCpy` in [`tcptrace.c`](tcptrace.c).
- **Public libpcap API**: Replaced non-standard internal `pcap_offline_read` with standard `pcap_dispatch` in [`tcpdump.c`](tcpdump.c).
- **Format String Hardening**: Fixed `%ld` / `%lu` format specifier mismatches on 64-bit systems in [`snoop.c`](snoop.c), [`etherpeek.c`](etherpeek.c), [`trace.c`](trace.c), and [`mod_http.c`](mod_http.c).
- **Native tcpdump Focus**: Streamlined capture reading to exclusively support standard `tcpdump` / `libpcap` format (`.pcap`, `.pcapng`, `.dmp`, compressed), deleting dead legacy format parsers (`snoop.c`, `etherpeek.c`, `netm.c`, `netscout.c`, `erf.c`, `ns.c`, `nlanr.c`).
- **Compiler Hardening & Safety**:
  - Fixed `-Werror=stringop-overflow` in [`trace.c`](trace.c) by computing safe destination bounds (`sizeof(buf1) - strlen(buf1) - 1`) for `strncat()`.
  - Fixed compiler warnings for unused return values (`warn_unused_result`) on modern GCC in [`plotter.c`](plotter.c), [`ns.c`](ns.c), and [`mod_tcplib.c`](mod_tcplib.c).
- **Stream Purging on Linux**: Added support for glibc `__fpurge()` via `<stdio_ext.h>` in [`compress.c`](compress.c) to properly purge stdio buffers when reopening compressed files.
- **Deprecated Function Replacement**: Replaced `sprintf()` with bounded `snprintf()` in [`ipv6.c`](ipv6.c) and [`print.c`](print.c).

### Memory Safety & Bug Fixes
- **LeakSanitizer Fixes**:
  - Fixed direct memory leak in `CheckArguments` in [`tcptrace.c`](tcptrace.c) by freeing `rc_path`.
  - Fixed memory leak in `FindBinary` in [`compress.c`](compress.c) by releasing `strdup` path buffer.
  - Fixed duplicate heap allocation leak of `tcp_pair` structures in `trace_init()` in [`trace.c`](trace.c).
- **Broken Pipe Handling**: Suppressed broken pipe warnings from early decompression pipe closure in [`compress.c`](compress.c).
- **C99/C23 Stdbool Compatibility**: Renamed AST union member `bool` to `boolval` in [`filter.h`](filter.h), [`filter.c`](filter.c), and [`filt_parser.y`](filt_parser.y) to prevent identifier conflicts with standard `<stdbool.h>`.
- **UBSan Alignment Fix**: Resolved unaligned memory access in TCP SACK option parsing in [`trace.c`](trace.c) by copying unaligned SACK option blocks using byte pointers and `memcpy()`.
- **Function Return Mismatch**: Fixed missing return value and void signature for `traffic_init_files` in [`mod_traffic.c`](mod_traffic.c).

### Housekeeping & Cleanup
- **Pruned Dead Binaries**: Deleted 25-year-old pre-compiled 32-bit Windows 9x/NT Cygwin libraries and headers (`cygwin-libs/`, `cygwin-includes/`, `README.cygwin`).
- **Linker Warning Cleanup**: Removed stale search paths from [`Makefile.in`](Makefile.in).
- **Git Ignore**: Updated [`.gitignore`](.gitignore) with modern CMake and test output patterns.

---

## [6.6.8] - 2006-01-05 (Shawn Ostermann)

### Fixed
- Fixed static memory returned in `names.c` (`EndpointName()`, `HostName()`, `HostAddr()`, `ServiceName()`) to cycle through static buffers to prevent clobbering in multi-argument `printf` calls.
- Resolved compiler warnings for uninitialized `dir` in `trace.c`.
- Fixed constant evaluation in filter expressions.
- Fixed handling of 0-length packets in `tcpdump` captures.

---

## [6.6.7] - 2004-11-04 (Shawn Ostermann, Mani, Josh Blanton)

### Fixed
- Fixed bugs in AVL search and connection lookup hashing.

---

## [6.6.6] - 2004-10-07 (Mani)

### Fixed
- Fixed callback function in `tcpdump.c` to prevent uninitialized data in `ip_buf`.

---

## [6.6.5] - 2004-10-01 (Mani, Josh Blanton)

### Added
- Integrated INBOUNDS intrusion detection support module.
- Added receive window (`-rwin.xpl`) graph generation.

### Changed
- Adjusted file format probe ordering to work around libpcap heuristic issues.
- Updated file operations in `mfiles.c` to use binary mode.

---

## [Historical Releases]
For earlier version history (v3.2.2 through v6.6.4), see the [CHANGES](CHANGES) file.
