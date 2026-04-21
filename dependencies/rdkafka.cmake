# ==============================================================================
# Copyright (C) 2025 Intel Corporation
#
# SPDX-License-Identifier: MIT
# ==============================================================================

include(ExternalProject)

# When changing version, you will also need to change the download hash
set(DESIRED_VERSION 2.12.1)

set(RDKAFKA_CONFIGURE_ARGS
    --prefix=${CMAKE_BINARY_DIR}/rdkafka-bin
)

set(_RDKAFKA_CONFIGURE_COMMAND
    ./configure ${RDKAFKA_CONFIGURE_ARGS}
)
set(_RDKAFKA_BUILD_COMMAND make)
set(_RDKAFKA_INSTALL_COMMAND make install)

if(CMAKE_CROSSCOMPILING)
    set(_RDKAFKA_CROSS_ENV)
    if(CMAKE_C_COMPILER)
        list(APPEND _RDKAFKA_CROSS_ENV CC=${CMAKE_C_COMPILER})
    endif()
    if(CMAKE_CXX_COMPILER)
        list(APPEND _RDKAFKA_CROSS_ENV CXX=${CMAKE_CXX_COMPILER})
    endif()
    if(CMAKE_AR)
        list(APPEND _RDKAFKA_CROSS_ENV AR=${CMAKE_AR})
    endif()
    if(CMAKE_RANLIB)
        list(APPEND _RDKAFKA_CROSS_ENV RANLIB=${CMAKE_RANLIB})
    endif()
    if(CMAKE_STRIP)
        list(APPEND _RDKAFKA_CROSS_ENV STRIP=${CMAKE_STRIP})
    endif()

    set(_RDKAFKA_ARCH_ABI_FLAGS "")
    if(DEFINED RISCV_ARCH_ABI_FLAGS)
        set(_RDKAFKA_ARCH_ABI_FLAGS "${RISCV_ARCH_ABI_FLAGS}")
    endif()

    set(_RDKAFKA_SYSROOT_FLAGS "")
    if(CMAKE_SYSROOT)
        set(_RDKAFKA_SYSROOT_FLAGS "--sysroot=${CMAKE_SYSROOT} -B${CMAKE_SYSROOT}/usr/lib/riscv64-linux-gnu -B${CMAKE_SYSROOT}/lib/riscv64-linux-gnu -L${CMAKE_SYSROOT}/usr/lib/riscv64-linux-gnu -L${CMAKE_SYSROOT}/lib/riscv64-linux-gnu -I${CMAKE_SYSROOT}/usr/include -I${CMAKE_SYSROOT}/usr/include/riscv64-linux-gnu")
    endif()

    set(_RDKAFKA_CFLAGS "${_RDKAFKA_ARCH_ABI_FLAGS} ${_RDKAFKA_SYSROOT_FLAGS} -Wno-error=cast-align")
    set(_RDKAFKA_CXXFLAGS "${_RDKAFKA_ARCH_ABI_FLAGS} ${_RDKAFKA_SYSROOT_FLAGS} -Wno-error=cast-align")
    set(_RDKAFKA_LDFLAGS "${_RDKAFKA_ARCH_ABI_FLAGS} ${_RDKAFKA_SYSROOT_FLAGS}")

    list(APPEND _RDKAFKA_CROSS_ENV "CFLAGS=${_RDKAFKA_CFLAGS}")
    list(APPEND _RDKAFKA_CROSS_ENV "CXXFLAGS=${_RDKAFKA_CXXFLAGS}")
    list(APPEND _RDKAFKA_CROSS_ENV "LDFLAGS=${_RDKAFKA_LDFLAGS}")

    if(CMAKE_C_COMPILER_TARGET)
        list(APPEND RDKAFKA_CONFIGURE_ARGS --host=${CMAKE_C_COMPILER_TARGET})
    else()
        list(APPEND RDKAFKA_CONFIGURE_ARGS --host=riscv64-linux-gnu)
    endif()

    set(_RDKAFKA_CONFIGURE_COMMAND
        ${CMAKE_COMMAND} -E env ${_RDKAFKA_CROSS_ENV} ./configure ${RDKAFKA_CONFIGURE_ARGS}
    )
    set(_RDKAFKA_BUILD_COMMAND
        ${CMAKE_COMMAND} -E env ${_RDKAFKA_CROSS_ENV} make
    )
    set(_RDKAFKA_INSTALL_COMMAND
        ${CMAKE_COMMAND} -E env ${_RDKAFKA_CROSS_ENV} make install
    )

    message(STATUS "librdkafka will be cross-compiled with ${CMAKE_C_COMPILER}")
endif()

ExternalProject_Add(
    rdkafka
    PREFIX ${CMAKE_BINARY_DIR}/rdkafka
    URL     https://github.com/edenhill/librdkafka/archive/v${DESIRED_VERSION}.tar.gz
    URL_MD5 86ed3acd2f9d9046250dea654cee59a8
    DOWNLOAD_EXTRACT_TIMESTAMP TRUE
    BUILD_IN_SOURCE 1
    BUILD_COMMAND ${_RDKAFKA_BUILD_COMMAND}
    INSTALL_COMMAND ${_RDKAFKA_INSTALL_COMMAND}
    TEST_COMMAND    ""
    CONFIGURE_COMMAND   ${_RDKAFKA_CONFIGURE_COMMAND}
)

if (INSTALL_DLSTREAMER)
    execute_process(COMMAND mkdir -p ${DLSTREAMER_INSTALL_PREFIX}/rdkafka
                    COMMAND cp -r ${CMAKE_BINARY_DIR}/rdkafka-bin/. ${DLSTREAMER_INSTALL_PREFIX}/rdkafka)
endif()
