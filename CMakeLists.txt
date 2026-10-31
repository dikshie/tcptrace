cmake_minimum_required(VERSION 3.16)
project(tcptrace VERSION 6.7.0 LANGUAGES C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED OFF)

include(CheckIncludeFile)
include(CheckFunctionExists)
include(CheckSymbolExists)

# User-configurable options
option(ENABLE_SANITIZERS "Enable Address and Undefined Behavior Sanitizers" OFF)
option(ENABLE_WERROR "Treat compiler warnings as errors" OFF)

if(ENABLE_SANITIZERS)
    add_compile_options(-fsanitize=address,undefined -fno-omit-frame-pointer)
    add_link_options(-fsanitize=address,undefined)
endif()

if(ENABLE_WERROR)
    add_compile_options(-Werror)
endif()

# Check functions and headers
check_function_exists(fpurge HAVE_FPURGE)
check_function_exists(mkstemp HAVE_MKSTEMP)
check_function_exists(valloc HAVE_VALLOC)
check_function_exists(inet_pton HAVE_INET_PTON)

# Find PCAP
find_package(PCAP QUIET)
if(NOT PCAP_FOUND)
    find_path(PCAP_INCLUDE_DIR NAMES pcap.h PATHS /usr/local/include /usr/include /opt/homebrew/include)
    find_library(PCAP_LIBRARY NAMES pcap PATHS /usr/local/lib /usr/lib /opt/homebrew/lib)
    if(PCAP_INCLUDE_DIR AND PCAP_LIBRARY)
        set(PCAP_FOUND TRUE)
    endif()
endif()

if(NOT PCAP_FOUND)
    message(FATAL_ERROR "libpcap was not found on this system.")
endif()

# Find Math Library
find_library(M_LIBRARY m)

# Parser and Scanner generation via Bison / Flex
find_package(BISON)
find_package(FLEX)

if(BISON_FOUND AND FLEX_FOUND)
    BISON_TARGET(FiltParser
        ${CMAKE_CURRENT_SOURCE_DIR}/filt_parser.y
        ${CMAKE_CURRENT_BINARY_DIR}/filt_parser.c
        DEFINES_FILE ${CMAKE_CURRENT_BINARY_DIR}/filt_parser.h
        COMPILE_FLAGS "-vd -p filtyy"
    )
    FLEX_TARGET(FiltScanner
        ${CMAKE_CURRENT_SOURCE_DIR}/filt_scanner.l
        ${CMAKE_CURRENT_BINARY_DIR}/filt_scanner.c
        COMPILE_FLAGS "-Pfiltyy"
    )
    ADD_FLEX_BISON_DEPENDENCY(FiltScanner FiltParser)
    set(PARSER_SOURCES ${BISON_FiltParser_OUTPUTS} ${FLEX_FiltScanner_OUTPUTS})
else()
    message(STATUS "Bison or Flex not found; using bundled pre-generated parser files.")
    set(PARSER_SOURCES
        ${CMAKE_CURRENT_SOURCE_DIR}/flex_bison/filt_parser.c
        ${CMAKE_CURRENT_SOURCE_DIR}/flex_bison/filt_scanner.c
    )
endif()

# Capture build metadata for version.c
string(TIMESTAMP BUILT_DATE "%a %b %d %Y %H:%M:%S")
set(BUILT_USER "$ENV{USER}")
if(NOT BUILT_USER)
    set(BUILT_USER "unknown")
endif()
cmake_host_system_information(RESULT BUILT_HOST QUERY HOSTNAME)

set_source_files_properties(version.c PROPERTIES
    COMPILE_DEFINITIONS
    "BUILT_USER=\"${BUILT_USER}\";BUILT_HOST=\"${BUILT_HOST}\";BUILT_DATE=\"${BUILT_DATE}\""
)

# Core source files
set(TCPTRACE_SOURCES
    avl.c
    compress.c
    dstring.c
    dyncounter.c
    erf.c
    etherpeek.c
    filter.c
    gcache.c
    ipv6.c
    mfiles.c
    names.c
    netm.c
    netscout.c
    nlanr.c
    ns.c
    output.c
    plotter.c
    pool.c
    poolaccess.c
    print.c
    rexmit.c
    snoop.c
    tcpdump.c
    tcptrace.c
    thruput.c
    trace.c
    udp.c
    version.c
    # Plug-in modules
    mod_collie.c
    mod_http.c
    mod_inbounds.c
    mod_realtime.c
    mod_rttgraph.c
    mod_slice.c
    mod_tcplib.c
    mod_traffic.c
    ${PARSER_SOURCES}
)

# Main executable
add_executable(tcptrace ${TCPTRACE_SOURCES})

target_include_directories(tcptrace PRIVATE
    ${CMAKE_CURRENT_BINARY_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/flex_bison
    ${PCAP_INCLUDE_DIR}
)

target_compile_definitions(tcptrace PRIVATE
    LOAD_MODULE_HTTP
    HTTP_SAFE
    HTTP_DUMP_TIMES
    LOAD_MODULE_TRAFFIC
    LOAD_MODULE_SLICE
    LOAD_MODULE_RTTGRAPH
    LOAD_MODULE_COLLIE
    LOAD_MODULE_REALTIME
    GROK_SNOOP
    GROK_TCPDUMP
    GROK_NETM
    GROK_ETHERPEEK
    GROK_NS
    GROK_NETSCOUT
    GROK_ERF
    YYTEXT_POINTER=1
    GUNZIP="gunzip"
    BUNZIP2="bunzip2"
)

if(HAVE_FPURGE)
    target_compile_definitions(tcptrace PRIVATE HAVE_FPURGE=1)
endif()
if(HAVE_MKSTEMP)
    target_compile_definitions(tcptrace PRIVATE HAVE_MKSTEMP=1)
endif()
if(HAVE_VALLOC)
    target_compile_definitions(tcptrace PRIVATE HAVE_VALLOC=1)
endif()
if(HAVE_INET_PTON)
    target_compile_definitions(tcptrace PRIVATE HAVE_INET_PTON=1)
endif()

target_link_libraries(tcptrace PRIVATE ${PCAP_LIBRARY})
if(M_LIBRARY)
    target_link_libraries(tcptrace PRIVATE ${M_LIBRARY})
    target_compile_definitions(tcptrace PRIVATE HAVE_LIBM=1)
endif()

# versnum utility
add_executable(versnum versnum.c)
target_include_directories(versnum PRIVATE
    ${CMAKE_CURRENT_BINARY_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${PCAP_INCLUDE_DIR}
)
target_link_libraries(versnum PRIVATE ${PCAP_LIBRARY})
if(M_LIBRARY)
    target_link_libraries(versnum PRIVATE ${M_LIBRARY})
endif()

# Testing with CTest
enable_testing()
add_test(NAME regression_test
    COMMAND "${CMAKE_CURRENT_SOURCE_DIR}/input/bin/run_regression.sh" "$<TARGET_FILE:tcptrace>"
    WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
)

# Installation rules
include(GNUInstallDirs)
install(TARGETS tcptrace RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
install(FILES tcptrace.man DESTINATION ${CMAKE_INSTALL_MANDIR}/man1 RENAME tcptrace.1)
