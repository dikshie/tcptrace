# tcptrace

[![CI](https://github.com/dikshie/tcptrace/actions/workflows/ci.yml/badge.svg)](https://github.com/dikshie/tcptrace/actions/workflows/ci.yml)
[![License: GPL-2.0](https://img.shields.io/badge/License-GPL%20v2-blue.svg)](COPYING)
[![C Standard](https://img.shields.io/badge/C-11%20%2F%2099-green.svg)](#)

`tcptrace` is a widely-used TCP connection analysis tool originally written by **Shawn Ostermann** at Ohio University. It reconstructs and analyzes TCP connections from packet dump files and produces comprehensive statistics, summaries, and graph data files.

---

## Features

- **Multi-format packet capture support**:
  - `tcpdump` / `libpcap` (`.pcap`, `.dmp`)
  - Sun `snoop` format
  - Macintosh Etherpeek format
  - HP / NetMetrix protocol analysis format
  - LBL Network Simulator (`ns`) format
  - NetScout ASCII format
  - Endace Technology DAG (`ERF`) format
- **Detailed connection analysis**:
  - Round-trip time (RTT) tracking and full-size sample distributions
  - Window advertisements, scale options, and zero-window probing
  - Retransmission detection, out-of-order delivery, and triple duplicate ACKs
  - Selective Acknowledgement (SACK) parsing
  - Throughput, idle times, and sequence number wrap-around handling
- **Plot and graph generation**:
  - Compatible with `xplot` (`-G` flag) for time-sequence graphs, throughput graphs, RTT graphs, and receive window graphs.
- **Modernized codebase**:
  - Standard C11 / C99 using `<stdint.h>` and `<inttypes.h>`.
  - Dual build system support: **CMake** (modern) and **Autotools** (traditional `./configure && make`).
  - Zero compiler warnings on modern Apple Clang and Linux GCC/Clang.
  - Sanitizer-verified: clean AddressSanitizer (ASan) and UndefinedBehaviorSanitizer (UBSan) validation.
  - Automated regression testing suite with 100% benchmark parity across 40 trace formats.

---

## Quick Start

### Prerequisites

- **C Compiler**: GCC or Clang (supporting C99/C11)
- **libpcap**: Development libraries and headers (`libpcap-dev` on Debian/Ubuntu, `libpcap` on macOS/Homebrew)
- **Bison & Flex**: For filter parsing (`bison`, `flex`)
- **CMake** (3.16+) or **GNU Make**

On Debian/Ubuntu:
```bash
sudo apt-get update
sudo apt-get install -y build-essential cmake libpcap-dev bison flex
```

On macOS (via Homebrew):
```bash
brew install cmake libpcap bison flex
```

---

### Building with CMake (Recommended)

```bash
# Configure
cmake -B build -DCMAKE_BUILD_TYPE=Release

# Build
cmake --build build -j

# Run regression tests
ctest --test-dir build --output-on-failure

# Optional: Install
sudo cmake --install build
```

#### CMake Build Options

- `-DENABLE_SANITIZERS=ON`: Compiles with AddressSanitizer and UndefinedBehaviorSanitizer (`-fsanitize=address,undefined`).
- `-DENABLE_WERROR=ON`: Treats all compiler warnings as errors.

```bash
cmake -B build-asan -DCMAKE_BUILD_TYPE=Debug -DENABLE_SANITIZERS=ON
cmake --build build-asan -j
ctest --test-dir build-asan --output-on-failure
```

---

### Building with Autotools

```bash
./configure
make -j
make test
```

---

## Usage Examples

```bash
# 1. Print help and options
tcptrace -h

# 2. Brief summary of connections in a trace file
tcptrace sample.pcap

# 3. Detailed analysis of all TCP connections
tcptrace -l sample.pcap

# 4. Generate xplot graph files (.xpl)
tcptrace -G sample.pcap

# 5. Continuous packet display with checksum verification
tcptrace -p --checksum sample.pcap

# 6. Filter connections (e.g. port 80 traffic only)
tcptrace -f'port 80' sample.pcap
```

---

## Automated Testing

`tcptrace` includes an automated regression test harness in `input/bin/run_regression.sh`:

```bash
# Run against the built binary
./input/bin/run_regression.sh ./build/tcptrace
```

This verifies packet parsing, connection tracking, checksum calculation, and sequence analysis against 40 benchmark trace suites across all link layers and encapsulations (Ethernet, FDDI, ATM, Raw IP, Linux Cooked Socket, PPP, and IPv6).

---

## History & Acknowledgments

`tcptrace` was conceived and maintained by **Shawn Ostermann** and contributors at Ohio University, supported by NASA Glenn Research Center, the National Science Foundation, and Sun Microsystems.

For more details, see [CHANGELOG.md](CHANGELOG.md) and the historical [CHANGES](CHANGES) document.

---

## License

`tcptrace` is licensed under the [GNU General Public License v2 (GPL-2.0)](COPYING).
