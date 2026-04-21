# ==============================================================================
# Copyright (C) 2026 Intel Corporation
#
# SPDX-License-Identifier: MIT
# ==============================================================================

include(ExternalProject)

set(PAHO_GIT_TAG v1.3.14)

set(PAHO_CMAKE_ARGS
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_INSTALL_PREFIX:PATH=${CMAKE_BINARY_DIR}/install
    -DPAHO_WITH_SSL=TRUE
    -DPAHO_HIGH_PERFORMANCE=TRUE
    -DPAHO_BUILD_DOCUMENTATION=FALSE
    -DPAHO_BUILD_SAMPLES=FALSE
    -DPAHO_ENABLE_TESTING=FALSE
    -DPAHO_BUILD_STATIC=FALSE
    -DPAHO_BUILD_SHARED=TRUE
)

if(CMAKE_CROSSCOMPILING)
    if(CMAKE_TOOLCHAIN_FILE)
        list(APPEND PAHO_CMAKE_ARGS
            -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}
        )
    endif()

    if(CMAKE_SYSROOT)
        list(APPEND PAHO_CMAKE_ARGS
            -DCMAKE_SYSROOT=${CMAKE_SYSROOT}
        )
    endif()
endif()

ExternalProject_Add(
    paho
    PREFIX ${CMAKE_BINARY_DIR}/paho
    GIT_REPOSITORY https://github.com/eclipse-paho/paho.mqtt.c.git
    GIT_TAG ${PAHO_GIT_TAG}
    GIT_SHALLOW TRUE
    UPDATE_COMMAND ""
    CMAKE_GENERATOR Ninja
    TEST_COMMAND ""
    CMAKE_ARGS ${PAHO_CMAKE_ARGS}
)
