# ==============================================================================
# Copyright (C) 2018-2026 Intel Corporation
#
# SPDX-License-Identifier: MIT
# ==============================================================================

set(TARGET_NAME "dlstreamer_gst_meta")

file(GLOB MAIN_SRC ${CMAKE_CURRENT_SOURCE_DIR}/*.c ${CMAKE_CURRENT_SOURCE_DIR}/*.cpp)
file(GLOB MAIN_HEADERS ${CMAKE_CURRENT_SOURCE_DIR}/*.h)

set(_DLS_GST_ANALYTICS_PKGCONFIG_DIRS)
if(ENABLE_RISCV)
        set(_DLS_GST_ANALYTICS_PKGCONFIG_CANDIDATES
                        "${CMAKE_BINARY_DIR}/deps/gstreamer-bin/lib/pkgconfig"
                        "${CMAKE_BINARY_DIR}/deps/install/lib/pkgconfig"
                        "${CMAKE_SOURCE_DIR}/build-riscv/deps/gstreamer-bin/lib/pkgconfig"
                        "${CMAKE_SOURCE_DIR}/build-riscv/deps/install/lib/pkgconfig")
else()
        set(_DLS_GST_ANALYTICS_PKGCONFIG_CANDIDATES
                        "${CMAKE_BINARY_DIR}/deps/gstreamer-bin/lib/pkgconfig"
                        "${CMAKE_BINARY_DIR}/deps/install/lib/pkgconfig"
                        "${CMAKE_SOURCE_DIR}/build/deps/gstreamer-bin/lib/pkgconfig"
                        "${CMAKE_SOURCE_DIR}/build/deps/install/lib/pkgconfig")
endif()

foreach(_dir IN LISTS _DLS_GST_ANALYTICS_PKGCONFIG_CANDIDATES)
        if(EXISTS "${_dir}")
                list(APPEND _DLS_GST_ANALYTICS_PKGCONFIG_DIRS "${_dir}")
        endif()
endforeach()

if(_DLS_GST_ANALYTICS_PKGCONFIG_DIRS)
        set(_DLS_PKG_CONFIG_PATH "$ENV{PKG_CONFIG_PATH}")
        foreach(_dir IN LISTS _DLS_GST_ANALYTICS_PKGCONFIG_DIRS)
                if(_DLS_PKG_CONFIG_PATH)
                        set(_DLS_PKG_CONFIG_PATH "${_dir}:${_DLS_PKG_CONFIG_PATH}")
                else()
                        set(_DLS_PKG_CONFIG_PATH "${_dir}")
                endif()
        endforeach()
        set(ENV{PKG_CONFIG_PATH} "${_DLS_PKG_CONFIG_PATH}")
endif()

pkg_check_modules(GSTANALYTICS QUIET gstreamer-analytics-1.0>=1.16)
if(NOT GSTANALYTICS_FOUND)
        message(FATAL_ERROR "gstreamer-analytics-1.0>=1.16 was not found")
endif()

add_library(${TARGET_NAME} SHARED ${MAIN_SRC} ${MAIN_HEADERS})
set_compile_flags(${TARGET_NAME})
if(WIN32)
    add_vs_version_resource(${TARGET_NAME})
endif()

target_include_directories(${TARGET_NAME}
        PUBLIC
                ${GSTREAMER_INCLUDE_DIRS}
                ${GSTVIDEO_INCLUDE_DIRS}
                ${GLIB2_INCLUDE_DIRS}
                ${GSTANALYTICS_INCLUDE_DIRS}
        PRIVATE
                ${GSTALLOC_INCLUDE_DIRS}
)

target_link_libraries(${TARGET_NAME}
        PUBLIC
                dlstreamer_api
        PRIVATE
                ${GSTREAMER_LIBRARIES}
                ${GSTVIDEO_LIBRARIES}
                ${GLIB2_LIBRARIES}
                ${GSTALLOC_LIBRARIES}
)

target_link_libraries(${TARGET_NAME} PRIVATE ${GSTANALYTICS_LIBRARIES})

install(TARGETS ${TARGET_NAME} DESTINATION ${DLSTREAMER_PLUGINS_INSTALL_PATH})

# Generate GObject Introspection (GIR) files
include(generate_gir.cmake)
