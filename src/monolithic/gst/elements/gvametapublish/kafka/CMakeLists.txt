# ==============================================================================
# Copyright (C) 2021 Intel Corporation
#
# SPDX-License-Identifier: MIT
# ==============================================================================

set (TARGET_NAME "gvametapublishkafka")

find_package(PkgConfig REQUIRED)
set(_KAFKA_LIBRARY_HINTS
    ${CMAKE_LIBRARY_PATH}
    ${CMAKE_SOURCE_DIR}/build-riscv/deps/rdkafka-bin/lib
    ${CMAKE_BINARY_DIR}/../deps/rdkafka-bin/lib
    ${CMAKE_BINARY_DIR}/deps/rdkafka-bin/lib
)
set(_KAFKA_INCLUDE_HINTS
    ${CMAKE_INCLUDE_PATH}
    ${CMAKE_SOURCE_DIR}/build-riscv/deps/rdkafka-bin/include
    ${CMAKE_BINARY_DIR}/../deps/rdkafka-bin/include
    ${CMAKE_BINARY_DIR}/deps/rdkafka-bin/include
)
find_library(KAFKA rdkafka++ HINTS ${_KAFKA_LIBRARY_HINTS} NO_CMAKE_FIND_ROOT_PATH REQUIRED)
find_path(KAFKA_INCLUDE_DIR librdkafka/rdkafkacpp.h HINTS ${_KAFKA_INCLUDE_HINTS} NO_CMAKE_FIND_ROOT_PATH REQUIRED)
pkg_check_modules(GSTREAMER gstreamer-1.0>=1.16 REQUIRED)


file (GLOB MAIN_SRC
    ${CMAKE_CURRENT_SOURCE_DIR}/*.cpp
)
file (GLOB MAIN_HEADERS
    ${CMAKE_CURRENT_SOURCE_DIR}/*.hpp
)

add_library(${TARGET_NAME} SHARED ${MAIN_SRC} ${MAIN_HEADERS})
set_compile_flags(${TARGET_NAME})

target_include_directories(${TARGET_NAME}
PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}
PRIVATE
    ${GLIB2_INCLUDE_DIRS}
    ${GSTREAMER_INCLUDE_DIRS}
    ${KAFKA_INCLUDE_DIR}
)

target_link_libraries(${TARGET_NAME}
PUBLIC
    gvametapublish
PRIVATE
    ${GSTREAMER_LIBRARIES}
    ${KAFKA}
)

install(TARGETS ${TARGET_NAME} DESTINATION ${DLSTREAMER_PLUGINS_INSTALL_PATH})
