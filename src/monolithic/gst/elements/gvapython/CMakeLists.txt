# ==============================================================================
# Copyright (C) 2020-2026 Intel Corporation
#
# SPDX-License-Identifier: MIT
# ==============================================================================

set (TARGET_NAME "gvapython")

find_package(PkgConfig REQUIRED)
pkg_check_modules(GLIB2 glib-2.0 REQUIRED)
pkg_check_modules(GSTREAMER gstreamer-1.0>=1.16 REQUIRED)
pkg_check_modules(PYGOBJECT pygobject-3.0)
find_package(Python 3.10 COMPONENTS Development)

set(_PYGOBJECT_INCLUDE_DIRS_NORMALIZED)
foreach(_inc IN LISTS PYGOBJECT_INCLUDE_DIRS)
    set(_normalized_inc "${_inc}")

    # pkg-config with PKG_CONFIG_SYSROOT_DIR can prepend sysroot to already
    # absolute local build paths (for bundled deps). Strip it when needed.
    if(CMAKE_SYSROOT AND _inc MATCHES "^${CMAKE_SYSROOT}/")
        string(REPLACE "${CMAKE_SYSROOT}" "" _candidate_inc "${_inc}")
        if(IS_ABSOLUTE "${_candidate_inc}" AND EXISTS "${_candidate_inc}")
            set(_normalized_inc "${_candidate_inc}")
        endif()
    endif()

    # If pkg-config returned a path that was prefixed by another sysroot,
    # recover the real workspace path for bundled gstreamer-bin includes.
    if(NOT EXISTS "${_normalized_inc}" AND _normalized_inc MATCHES "/build-riscv/deps/gstreamer-bin/")
        string(REGEX REPLACE "^.*(/build-riscv/deps/gstreamer-bin/.*)$" "\\1" _bundled_tail "${_normalized_inc}")
        if(_bundled_tail MATCHES "^/build-riscv/deps/gstreamer-bin/")
            set(_candidate_inc "${PROJECT_SOURCE_DIR}${_bundled_tail}")
            if(EXISTS "${_candidate_inc}")
                set(_normalized_inc "${_candidate_inc}")
            endif()
        endif()
    endif()

    list(APPEND _PYGOBJECT_INCLUDE_DIRS_NORMALIZED "${_normalized_inc}")

    # Sources include <pygobject-3.0/pygobject.h>, so keep parent include dir.
    if(_normalized_inc MATCHES "/pygobject-3\\.0$")
        get_filename_component(_pygobject_parent_inc "${_normalized_inc}" DIRECTORY)
        list(APPEND _PYGOBJECT_INCLUDE_DIRS_NORMALIZED "${_pygobject_parent_inc}")
    endif()
endforeach()
list(REMOVE_DUPLICATES _PYGOBJECT_INCLUDE_DIRS_NORMALIZED)

if (NOT PYGOBJECT_FOUND OR NOT Python_FOUND)
    message("Python library not found, skipping gvapython build")
    return()
endif()

file (GLOB MAIN_SRC
    ${CMAKE_CURRENT_SOURCE_DIR}/*.c
    ${CMAKE_CURRENT_SOURCE_DIR}/*.cpp
    )

file (GLOB MAIN_HEADERS
    ${CMAKE_CURRENT_SOURCE_DIR}/*.h
)

add_library(${TARGET_NAME} SHARED ${MAIN_SRC} ${MAIN_HEADERS})
set_compile_flags(${TARGET_NAME})
if(WIN32)
    add_vs_version_resource(${TARGET_NAME})
endif()

target_include_directories(${TARGET_NAME}
PRIVATE
    ${GLIB2_INCLUDE_DIRS}
    ${GSTREAMER_INCLUDE_DIRS}
    ${Python_INCLUDE_DIRS}
    ${_PYGOBJECT_INCLUDE_DIRS_NORMALIZED}
)

target_link_libraries(${TARGET_NAME}
PRIVATE
    ${GSTREAMER_LIBRARIES}
    ${GLIB2_LIBRARIES}
    ${Python_LIBRARIES}
    ${PYGOBJECT_LIBRARIES}
    common
    utils
)

install(TARGETS ${TARGET_NAME} DESTINATION ${DLSTREAMER_PLUGINS_INSTALL_PATH})
