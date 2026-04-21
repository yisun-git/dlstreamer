# ==============================================================================
# RISC-V cross-compilation toolchain for DL Streamer
#
# Usage example:
#   cmake -S . -B build-riscv \
#     -DCMAKE_TOOLCHAIN_FILE=cmake/toolchains/riscv-vsi.cmake
#
# Override defaults if needed:
#   -DRISCV_TOOLCHAIN_ROOT=/path/to/toolchain
#   -DRISCV_SYSROOT=/path/to/sysroot
# ==============================================================================

set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR riscv64)

get_filename_component(DLSTREAMER_SOURCE_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)

set(RISCV_TOOLCHAIN_ROOT "/opt/dlstreamer/riscv/toolchain" CACHE PATH "RISC-V toolchain root")
set(RISCV_SYSROOT "/opt/dlstreamer/riscv/sysroot" CACHE PATH "RISC-V target sysroot")

# Required by target Ubuntu runtime compatibility.
set(RISCV_ARCH_ABI_FLAGS "-march=rv64imafdc -mabi=lp64d" CACHE STRING "RISC-V ISA/ABI flags")

set(_RISCV_COMPILER_HINTS
    "${RISCV_TOOLCHAIN_ROOT}/bin"
    "${RISCV_TOOLCHAIN_ROOT}/gcc/bin"
)

find_program(RISCV_GCC
    NAMES
        riscv64-unknown-linux-gnu-gcc
        riscv64-linux-gnu-gcc
        riscv64-buildroot-linux-gnu-gcc
        riscv64-elf-gcc
    HINTS ${_RISCV_COMPILER_HINTS}
    NO_DEFAULT_PATH
)

find_program(RISCV_GXX
    NAMES
        riscv64-unknown-linux-gnu-g++
        riscv64-linux-gnu-g++
        riscv64-buildroot-linux-gnu-g++
        riscv64-elf-g++
    HINTS ${_RISCV_COMPILER_HINTS}
    NO_DEFAULT_PATH
)

if(NOT RISCV_GCC OR NOT RISCV_GXX)
    message(FATAL_ERROR
        "RISC-V compiler not found under ${RISCV_TOOLCHAIN_ROOT}. "
        "Please extract/install the toolchain and reconfigure with "
        "-DRISCV_TOOLCHAIN_ROOT=<toolchain_root>."
    )
endif()

set(CMAKE_C_COMPILER "${RISCV_GCC}")
set(CMAKE_CXX_COMPILER "${RISCV_GXX}")
set(CMAKE_SYSROOT "${RISCV_SYSROOT}")

# Work around mismatched toolchain include-fixed/pthread.h by forcing
# an early pthread.h that forwards to the target sysroot header.
set(RISCV_INCLUDE_OVERRIDE_DIR "${CMAKE_BINARY_DIR}/riscv-include-overrides")
file(MAKE_DIRECTORY "${RISCV_INCLUDE_OVERRIDE_DIR}")
file(WRITE "${RISCV_INCLUDE_OVERRIDE_DIR}/pthread.h"
"#ifndef DLSTREAMER_RISCV_PTHREAD_OVERRIDE_H\n"
"#define DLSTREAMER_RISCV_PTHREAD_OVERRIDE_H\n"
"#include \"${RISCV_SYSROOT}/usr/include/pthread.h\"\n"
"#endif\n")

# Some target sysroots provide libva runtime libraries without development
# headers. Stage host VA headers into include overrides so <va/...> includes
# remain available in cross builds.
if(NOT EXISTS "${RISCV_SYSROOT}/usr/include/va/va.h" AND EXISTS "/usr/include/va/va.h")
    file(COPY "/usr/include/va" DESTINATION "${RISCV_INCLUDE_OVERRIDE_DIR}")
endif()

# Some sysroots use Debian-style multiarch directories (riscv64-linux-gnu),
# while this toolchain targets riscv64-unknown-linux-gnu. Add explicit search
# paths so startup objects (crt1.o, crti.o, ...) are resolvable.
set(RISCV_MULTIARCH_LIBDIRS
    "-L${RISCV_SYSROOT}/usr/lib/riscv64-linux-gnu"
    "-L${RISCV_SYSROOT}/lib/riscv64-linux-gnu"
)
string(JOIN " " RISCV_MULTIARCH_LIB_FLAGS ${RISCV_MULTIARCH_LIBDIRS})

set(RISCV_STARTFILE_PREFIX_DIRS
    "-B${RISCV_SYSROOT}/usr/lib/riscv64-linux-gnu"
    "-B${RISCV_SYSROOT}/lib/riscv64-linux-gnu"
)
string(JOIN " " RISCV_STARTFILE_PREFIX_FLAGS ${RISCV_STARTFILE_PREFIX_DIRS})

# Multiarch sysroots keep glibc bits/* headers under arch-specific include dir.
set(RISCV_MULTIARCH_INCLUDE_DIRS
    "-I${RISCV_INCLUDE_OVERRIDE_DIR}"
    "-isystem ${DLSTREAMER_SOURCE_ROOT}/build-riscv/deps/gstreamer-bin/include/gstreamer-1.0"
    "-isystem ${RISCV_SYSROOT}/usr/lib/riscv64-linux-gnu/glib-2.0/include"
    "-isystem ${RISCV_SYSROOT}/usr/include/glib-2.0"
    "-isystem ${RISCV_SYSROOT}/usr/include/sysprof-6"
    "-isystem ${RISCV_SYSROOT}/usr/include/libdrm"
    "-isystem ${RISCV_SYSROOT}/usr/include/riscv64-linux-gnu"
)
string(JOIN " " RISCV_MULTIARCH_INCLUDE_FLAGS ${RISCV_MULTIARCH_INCLUDE_DIRS})

set(CMAKE_C_FLAGS_INIT "${RISCV_ARCH_ABI_FLAGS} ${RISCV_STARTFILE_PREFIX_FLAGS} ${RISCV_MULTIARCH_INCLUDE_FLAGS}")
set(CMAKE_CXX_FLAGS_INIT "${RISCV_ARCH_ABI_FLAGS} ${RISCV_STARTFILE_PREFIX_FLAGS} ${RISCV_MULTIARCH_INCLUDE_FLAGS}")
set(CMAKE_EXE_LINKER_FLAGS_INIT "${RISCV_ARCH_ABI_FLAGS} --sysroot=${RISCV_SYSROOT} ${RISCV_STARTFILE_PREFIX_FLAGS} ${RISCV_MULTIARCH_LIB_FLAGS}")
set(CMAKE_SHARED_LINKER_FLAGS_INIT "${RISCV_ARCH_ABI_FLAGS} --sysroot=${RISCV_SYSROOT} ${RISCV_STARTFILE_PREFIX_FLAGS} ${RISCV_MULTIARCH_LIB_FLAGS}")
set(CMAKE_MODULE_LINKER_FLAGS_INIT "${RISCV_ARCH_ABI_FLAGS} --sysroot=${RISCV_SYSROOT} ${RISCV_STARTFILE_PREFIX_FLAGS} ${RISCV_MULTIARCH_LIB_FLAGS}")

# Keep host tools discoverable, but resolve target headers/libs/packages via sysroot/toolchain only.
set(CMAKE_FIND_ROOT_PATH "${RISCV_TOOLCHAIN_ROOT}" "${RISCV_SYSROOT}")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

# Help pkg-config resolve target .pc files correctly when cross-compiling.
# Prefer dependency pkgconfig directories from the repository RISC-V deps tree
# to avoid host/sysroot mixups during try_compile checks.
get_filename_component(_DLSTREAMER_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
set(RISCV_DEPS_ROOT "${_DLSTREAMER_ROOT}/build-riscv/deps" CACHE PATH "RISC-V dependency root for pkg-config")
set(_RISCV_PKGCONFIG_STAGING_DIR "${RISCV_DEPS_ROOT}/install/lib/pkgconfig")
file(MAKE_DIRECTORY "${_RISCV_PKGCONFIG_STAGING_DIR}")
file(MAKE_DIRECTORY "${RISCV_DEPS_ROOT}/install/lib")

if(EXISTS "${RISCV_SYSROOT}/usr/lib/riscv64-linux-gnu/libva.so.2")
    if(NOT EXISTS "${RISCV_DEPS_ROOT}/install/lib/libva.so")
        file(CREATE_LINK "${RISCV_SYSROOT}/usr/lib/riscv64-linux-gnu/libva.so.2"
            "${RISCV_DEPS_ROOT}/install/lib/libva.so" SYMBOLIC)
    endif()
endif()

if(EXISTS "${RISCV_SYSROOT}/usr/lib/riscv64-linux-gnu/libva-drm.so.2")
    if(NOT EXISTS "${RISCV_DEPS_ROOT}/install/lib/libva-drm.so")
        file(CREATE_LINK "${RISCV_SYSROOT}/usr/lib/riscv64-linux-gnu/libva-drm.so.2"
            "${RISCV_DEPS_ROOT}/install/lib/libva-drm.so" SYMBOLIC)
    endif()
endif()

if(EXISTS "${RISCV_SYSROOT}/usr/lib/riscv64-linux-gnu/libgstva-1.0.so.0")
    if(NOT EXISTS "${RISCV_DEPS_ROOT}/install/lib/libgstva-1.0.so")
        file(CREATE_LINK "${RISCV_SYSROOT}/usr/lib/riscv64-linux-gnu/libgstva-1.0.so.0"
            "${RISCV_DEPS_ROOT}/install/lib/libgstva-1.0.so" SYMBOLIC)
    endif()
endif()

# Some sysroots only provide versioned libdl shared objects (libdl.so.2)
# and static archives (libdl.a). Stage an unversioned linker name.
if(EXISTS "${RISCV_SYSROOT}/usr/lib/riscv64-linux-gnu/libdl.so.2")
    if(NOT EXISTS "${RISCV_DEPS_ROOT}/install/lib/libdl.so")
        file(CREATE_LINK "${RISCV_SYSROOT}/usr/lib/riscv64-linux-gnu/libdl.so.2"
            "${RISCV_DEPS_ROOT}/install/lib/libdl.so" SYMBOLIC)
    endif()
endif()

if(EXISTS "${RISCV_SYSROOT}/usr/lib/riscv64-linux-gnu/libgstanalytics-1.0.so.0")
    if(NOT EXISTS "${RISCV_DEPS_ROOT}/install/lib/libgstanalytics-1.0.so")
        file(CREATE_LINK "${RISCV_SYSROOT}/usr/lib/riscv64-linux-gnu/libgstanalytics-1.0.so.0"
            "${RISCV_DEPS_ROOT}/install/lib/libgstanalytics-1.0.so" SYMBOLIC)
    endif()
endif()

if(NOT EXISTS "${_RISCV_PKGCONFIG_STAGING_DIR}/libva.pc" AND
   EXISTS "${RISCV_SYSROOT}/usr/lib/riscv64-linux-gnu/libva.so.2")
    file(WRITE "${_RISCV_PKGCONFIG_STAGING_DIR}/libva.pc" [=[
prefix=/usr
exec_prefix=${prefix}
libdir=${exec_prefix}/lib/riscv64-linux-gnu
includedir=${prefix}/include

Name: libva
Description: Video Acceleration (VA) API
Version: 2.22.0
Libs: -L${libdir} -l:libva.so.2
Cflags: -I${includedir}
]=])
endif()

if(NOT EXISTS "${_RISCV_PKGCONFIG_STAGING_DIR}/libva-drm.pc" AND
   EXISTS "${RISCV_SYSROOT}/usr/lib/riscv64-linux-gnu/libva-drm.so.2")
    file(WRITE "${_RISCV_PKGCONFIG_STAGING_DIR}/libva-drm.pc" [=[
prefix=/usr
exec_prefix=${prefix}
libdir=${exec_prefix}/lib/riscv64-linux-gnu
includedir=${prefix}/include

Name: libva-drm
Description: Video Acceleration (VA) API for DRM
Version: 2.22.0
Requires: libva
Libs: -L${libdir} -l:libva-drm.so.2
Cflags: -I${includedir}
]=])
endif()

if(EXISTS "${RISCV_SYSROOT}/usr/lib/riscv64-linux-gnu/libgstanalytics-1.0.so.0")
    file(WRITE "${_RISCV_PKGCONFIG_STAGING_DIR}/gstreamer-analytics-1.0.pc" [=[
prefix=/usr
exec_prefix=${prefix}
libdir=${exec_prefix}/lib/riscv64-linux-gnu
includedir=${prefix}/include

Name: gstreamer-analytics-1.0
Description: GStreamer analytics library
Version: 1.26.6
Requires: gstreamer-video-1.0 >= 1.16, gstreamer-1.0 >= 1.16
Libs: -L${libdir} -l:libgstanalytics-1.0.so.0 -lm
Cflags: -I${pcfiledir}/../../gstreamer-bin/include/gstreamer-1.0
]=])
endif()

set(_RISCV_PKGCONFIG_DIRS
    "${RISCV_DEPS_ROOT}/install/lib/pkgconfig"
    "${RISCV_DEPS_ROOT}/rdkafka-bin/lib/pkgconfig"
    "${RISCV_SYSROOT}/usr/lib/pkgconfig"
    "${RISCV_SYSROOT}/usr/share/pkgconfig"
    "${RISCV_SYSROOT}/usr/lib/riscv64-linux-gnu/pkgconfig"
    "${RISCV_SYSROOT}/lib/riscv64-linux-gnu/pkgconfig"
)
list(JOIN _RISCV_PKGCONFIG_DIRS ":" _RISCV_PKGCONFIG_LIBDIR)
set(ENV{PKG_CONFIG_SYSROOT_DIR} "${RISCV_SYSROOT}")
set(ENV{PKG_CONFIG_LIBDIR} "${_RISCV_PKGCONFIG_LIBDIR}")
