# ==============================================================================
# Copyright (C) 2021-2024 Intel Corporation
#
# SPDX-License-Identifier: MIT
# ==============================================================================

set (TARGET_NAME "gvametapublishmqtt")

find_package(PkgConfig REQUIRED)
find_library(UUID uuid REQUIRED)
set(_MQTT_LIBRARY_HINTS
    ${CMAKE_LIBRARY_PATH}
    ${CMAKE_SOURCE_DIR}/build-riscv/deps/install/lib
    ${CMAKE_BINARY_DIR}/../deps/install/lib
    ${CMAKE_BINARY_DIR}/deps/install/lib
)
set(_MQTT_INCLUDE_HINTS
    ${CMAKE_INCLUDE_PATH}
    ${CMAKE_SOURCE_DIR}/build-riscv/deps/install/include
    ${CMAKE_BINARY_DIR}/../deps/install/include
    ${CMAKE_BINARY_DIR}/deps/install/include
)
find_library(MQTT NAMES paho-mqtt3as paho-mqtt3a HINTS ${_MQTT_LIBRARY_HINTS} NO_CMAKE_FIND_ROOT_PATH REQUIRED)
find_path(MQTT_INCLUDE_DIR MQTTAsync.h HINTS ${_MQTT_INCLUDE_HINTS} NO_CMAKE_FIND_ROOT_PATH REQUIRED)
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
PRIVATE
    ${GLIB2_INCLUDE_DIRS}
    ${GSTREAMER_INCLUDE_DIRS}
    ${MQTT_INCLUDE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}
)

target_link_libraries(${TARGET_NAME}
PRIVATE
    ${GSTREAMER_LIBRARIES}
    ${MQTT}
    ${UUID}
    common
    gvametapublish
)

install(TARGETS ${TARGET_NAME} DESTINATION ${DLSTREAMER_PLUGINS_INSTALL_PATH})
