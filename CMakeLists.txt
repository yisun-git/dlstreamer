# ==============================================================================
# Copyright (C) 2018-2026 Intel Corporation
#
# SPDX-License-Identifier: MIT
# ==============================================================================

cmake_minimum_required(VERSION 3.20)

project(DL_Streamer C CXX)

include_directories("${CMAKE_BINARY_DIR}/deps/install/include;${CMAKE_BINARY_DIR}/deps/gstreamer-bin/include;${CMAKE_BINARY_DIR}/deps/opencv-bin/include")

if (WIN32)
    add_compile_options("$<$<C_COMPILER_ID:MSVC>:/utf-8>")
    add_compile_options("$<$<CXX_COMPILER_ID:MSVC>:/utf-8>")
endif()

if(NOT(UNIX) AND NOT(WIN32))
    message(FATAL_ERROR "Only UNIX and Windows supported")
endif()

if (NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
    message(STATUS "CMAKE_BUILD_TYPE is undefined. Set default build type ${CMAKE_BUILD_TYPE}.")
endif()

# Define version
set(VERSION_MAJOR 2026)
set(VERSION_MINOR 0)
set(VERSION_PATCH 0)

include(cmake/version.cmake)
include(cmake/vs_version.cmake)

if (NOT DEFINED GIT_INFO OR "${GIT_INFO}" STREQUAL "")
    set(GIT_INFO "0")
    message(INFO "GIT_INFO is undefined. Set default value ${GIT_INFO}.")
endif()

configure_file(cmake/version.txt.in version.txt)

set(PRODUCT_VERSION ${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH})
set(PLUGIN_VERSION ${PRODUCT_VERSION})

# Propagate version to plugins

add_definitions(-DPLUGIN_VERSION="${PLUGIN_VERSION}")
add_definitions(-DPACKAGE="dlstreamer")
add_definitions(-DPACKAGE_NAME="Deep Learning Streamer elements")
add_definitions(-DGST_PACKAGE_ORIGIN="https://github.com/open-edge-platform/dlstreamer/tree/main")
add_definitions(-DPLUGIN_LICENSE="MIT/X11")
add_definitions(-DPRODUCT_FULL_NAME="Deep Learning Streamer")
if(WIN32)
    add_definitions(-DNOMINMAX)
endif()

# Helper macros and functions

function (set_compile_flags TARGET)
    target_compile_options(${TARGET} PRIVATE $<$<COMPILE_LANGUAGE:C>:${C_FLAGS}> $<$<COMPILE_LANGUAGE:CXX>:${CXX_FLAGS}>)
    if (CMAKE_CXX_COMPILER STREQUAL "icpx")
        target_compile_options(${TARGET} PRIVATE -Wno-tautological-constant-compare)

        if (CMAKE_BUILD_TYPE STREQUAL "Debug")
            target_compile_options(${TARGET} PRIVATE -Wno-debug-disables-optimization -Rno-debug-disables-optimization -Wno-unknown-warning-option)
        endif()

        string(REPLACE "-fno-strict-overflow" "" CXX_TMP_FLAGS "${CMAKE_CXX_FLAGS}")
        set(CMAKE_CXX_FLAGS ${CXX_TMP_FLAGS} PARENT_SCOPE)
    endif()
endfunction(set_compile_flags)

# Set output paths
if (NOT(BIN_FOLDER))
    if("${CMAKE_SIZEOF_VOID_P}" EQUAL "8")
        set(BIN_FOLDER intel64)
    else()
        set(BIN_FOLDER ia32)
    endif()
endif()

# Use generator expression for build type
set (CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/${BIN_FOLDER}/$<CONFIG>/lib)
set (CMAKE_PLUGIN_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/${BIN_FOLDER}/$<CONFIG>/lib/gstreamer-1.0)
set (CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/${BIN_FOLDER}/$<CONFIG>/lib)
set (CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/${BIN_FOLDER}/$<CONFIG>/bin)
set (CMAKE_SAMPLES_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/${BIN_FOLDER}/$<CONFIG>/samples)

# For multi-config generators (Visual Studio), set per-configuration output directories to prevent appending an additional config subdirectory.
# For single-config generators (Makefiles), CMAKE_CONFIGURATION_TYPES is empty, so this loop is skipped.
foreach(OUTPUTCONFIG ${CMAKE_CONFIGURATION_TYPES})
    string(TOUPPER ${OUTPUTCONFIG} OUTPUTCONFIG_UPPER)
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY_${OUTPUTCONFIG_UPPER} ${CMAKE_BINARY_DIR}/${BIN_FOLDER}/${OUTPUTCONFIG}/lib)
    set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY_${OUTPUTCONFIG_UPPER} ${CMAKE_BINARY_DIR}/${BIN_FOLDER}/${OUTPUTCONFIG}/lib)
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_${OUTPUTCONFIG_UPPER} ${CMAKE_BINARY_DIR}/${BIN_FOLDER}/${OUTPUTCONFIG}/bin)
endforeach()

set (DLSTREAMER_LIBRARIES_INSTALL_PATH lib)
set (DLSTREAMER_PLUGINS_INSTALL_PATH ${DLSTREAMER_LIBRARIES_INSTALL_PATH}/gstreamer-1.0)
set (DLSTREAMER_HEADERS_INSTALL_PATH include)

# include and lib folders of this project
set (DLSTREAMER_BASE_DIR ${CMAKE_CURRENT_SOURCE_DIR})
set (DLSTREAMER_INCLUDE_DIRS ${DLSTREAMER_BASE_DIR}/include/dlstreamer)
set (DLSTREAMER_LIBRARIES ${CMAKE_LIBRARY_OUTPUT_DIRECTORY})

# Options

include(CMakeDependentOption)

option(ENABLE_SAMPLES "Parameter to enable samples building" ON)
cmake_dependent_option(TREAT_WARNING_AS_ERROR "Treat build warnings as errors" ON "UNIX" OFF)
cmake_dependent_option(ENABLE_ITT "Enable ITT for tracing" ON "UNIX AND NOT ${CMAKE_SYSTEM_PROCESSOR} STREQUAL aarch64" OFF)
cmake_dependent_option(ENABLE_VAAPI "Parameter to enable VAAPI for image pre-processing" ON "UNIX" ON)
cmake_dependent_option(ENABLE_PAHO_INSTALLATION "Enables paho-mqtt3c installation" OFF "UNIX" OFF)
cmake_dependent_option(ENABLE_TESTS "Parameter to enable tests building" ON "UNIX" OFF)
cmake_dependent_option(ENABLE_FUZZING "Parameter to enable fuzzy tests building" OFF "UNIX" OFF)
cmake_dependent_option(ENABLE_RDKAFKA_INSTALLATION "Enables rdkafka installation" OFF "UNIX" OFF)
option(ENABLE_AUDIO_INFERENCE_ELEMENTS "Enables audio inference elements" ON)
option(ENABLE_REALSENSE "Parameter to enable RelaseSense plugin compilation" OFF)
option(ENABLE_GENAI "Enables GenAI elements" OFF)
option(ENABLE_RISCV "Enable RISC-V build mode (disables OpenVINO-dependent components)" ON)
set(VSI_UMD_LIB_DIR "" CACHE PATH "Directory containing libNBGlinker.so and libVIPhal.so")
# Enable GenAI by default on Windows.
# It can be enabled on Ubuntu but there is no support for Fedora.
if(WIN32)
    set(ENABLE_GENAI ON)
endif()

if(ENABLE_RISCV)
    if(NOT CMAKE_SYSTEM_PROCESSOR MATCHES "^riscv")
        message(FATAL_ERROR
            "ENABLE_RISCV=ON requires a RISC-V target toolchain/configuration. "
            "Current CMAKE_SYSTEM_PROCESSOR='${CMAKE_SYSTEM_PROCESSOR}'. "
            "Use -DCMAKE_TOOLCHAIN_FILE=cmake/toolchains/riscv-vsi.cmake or run make build-riscv."
        )
    endif()
    set(ENABLE_OPENVINO OFF)
else()
    set(ENABLE_OPENVINO ON)
endif()

if(ENABLE_OPENVINO)
    find_package(OpenVINO QUIET COMPONENTS Runtime)
    if(NOT OpenVINO_FOUND)
        message(WARNING "OpenVINO Runtime not found. Disabling OpenVINO-dependent components.")
        set(ENABLE_OPENVINO OFF)
    endif()
endif()

if(NOT ENABLE_OPENVINO)
    if(ENABLE_GENAI)
        message(WARNING "ENABLE_GENAI requires OpenVINO. Disabling ENABLE_GENAI.")
        set(ENABLE_GENAI OFF CACHE BOOL "Enables GenAI elements" FORCE)
    endif()
    if(ENABLE_AUDIO_INFERENCE_ELEMENTS)
        message(WARNING "ENABLE_AUDIO_INFERENCE_ELEMENTS requires OpenVINO. Disabling ENABLE_AUDIO_INFERENCE_ELEMENTS.")
        set(ENABLE_AUDIO_INFERENCE_ELEMENTS OFF CACHE BOOL "Enables audio inference elements" FORCE)
    endif()
endif()

message("ENABLE_PAHO_INSTALLATION=${ENABLE_PAHO_INSTALLATION}")
message("ENABLE_RDKAFKA_INSTALLATION=${ENABLE_RDKAFKA_INSTALLATION}")
message("ENABLE_REALSENSE=${ENABLE_REALSENSE}")

if(ENABLE_RISCV)
    if(NOT UNIX)
        message(FATAL_ERROR "ENABLE_RISCV is supported on UNIX platforms only")
    endif()

    set(_VSI_UMD_CANDIDATE_DIRS)
    if(VSI_UMD_LIB_DIR)
        list(APPEND _VSI_UMD_CANDIDATE_DIRS "${VSI_UMD_LIB_DIR}")
    endif()
    if(DEFINED ENV{VSI_UMD_LIB_DIR} AND NOT "$ENV{VSI_UMD_LIB_DIR}" STREQUAL "")
        list(APPEND _VSI_UMD_CANDIDATE_DIRS "$ENV{VSI_UMD_LIB_DIR}")
    endif()
    list(APPEND _VSI_UMD_CANDIDATE_DIRS
        "${CMAKE_SOURCE_DIR}/thirdparty/vsi/riscv64/lib"
        "${CMAKE_SOURCE_DIR}/../vsi/vsi_ubuntu_files"
    )
    list(REMOVE_DUPLICATES _VSI_UMD_CANDIDATE_DIRS)

    find_library(VSI_NBGLINKER_LIB NAMES NBGlinker libNBGlinker.so HINTS ${_VSI_UMD_CANDIDATE_DIRS})
    find_library(VSI_VIPHAL_LIB NAMES VIPhal libVIPhal.so HINTS ${_VSI_UMD_CANDIDATE_DIRS})

    if(NOT VSI_NBGLINKER_LIB OR NOT VSI_VIPHAL_LIB)
        message(FATAL_ERROR
            "ENABLE_RISCV=ON but failed to find both libNBGlinker.so and libVIPhal.so. "
            "Checked candidate dirs: ${_VSI_UMD_CANDIDATE_DIRS}. "
            "Please pass -DVSI_UMD_LIB_DIR=<dir> or make VSI_UMD_LIB_DIR=<dir>."
        )
    endif()

    get_filename_component(VSI_UMD_LIB_DIR "${VSI_NBGLINKER_LIB}" DIRECTORY)

    add_library(viplite_umd INTERFACE)
    target_link_libraries(viplite_umd INTERFACE ${VSI_NBGLINKER_LIB} ${VSI_VIPHAL_LIB})

    message(STATUS "ENABLE_RISCV=ON")
    message(STATUS "VSI_UMD_LIB_DIR=${VSI_UMD_LIB_DIR}")
endif()

# Define compiler flags

set(_DLS_LOCAL_PKGCONFIG_DIRS)
if(ENABLE_RISCV)
    set(_DLS_LOCAL_PKGCONFIG_CANDIDATES
            "${CMAKE_BINARY_DIR}/deps/install/lib/pkgconfig"
            "${CMAKE_BINARY_DIR}/deps/gstreamer-bin/lib/pkgconfig"
            "${CMAKE_SOURCE_DIR}/build-riscv/deps/install/lib/pkgconfig"
            "${CMAKE_SOURCE_DIR}/build-riscv/deps/gstreamer-bin/lib/pkgconfig")
else()
    set(_DLS_LOCAL_PKGCONFIG_CANDIDATES
            "${CMAKE_BINARY_DIR}/deps/install/lib/pkgconfig"
            "${CMAKE_BINARY_DIR}/deps/gstreamer-bin/lib/pkgconfig"
            "${CMAKE_SOURCE_DIR}/build/deps/install/lib/pkgconfig"
            "${CMAKE_SOURCE_DIR}/build/deps/gstreamer-bin/lib/pkgconfig")
endif()

foreach(_dir IN LISTS _DLS_LOCAL_PKGCONFIG_CANDIDATES)
    if(EXISTS "${_dir}")
        list(APPEND _DLS_LOCAL_PKGCONFIG_DIRS "${_dir}")
    endif()
endforeach()

if(_DLS_LOCAL_PKGCONFIG_DIRS)
    set(_DLS_PKG_CONFIG_PATH "$ENV{PKG_CONFIG_PATH}")
    foreach(_dir IN LISTS _DLS_LOCAL_PKGCONFIG_DIRS)
        if(_DLS_PKG_CONFIG_PATH)
            set(_DLS_PKG_CONFIG_PATH "${_dir}:${_DLS_PKG_CONFIG_PATH}")
        else()
            set(_DLS_PKG_CONFIG_PATH "${_dir}")
        endif()
    endforeach()
    set(ENV{PKG_CONFIG_PATH} "${_DLS_PKG_CONFIG_PATH}")
endif()

if(WIN32)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /permissive-")
    # disabled some warnings to reduce log size
    set(CMAKE_CXX_FLAGS_RELEASE "/O2 -wd4005 -wd4267 -wd4297 -wd4244 -wd4273 -wd4141 -wd4805")

    set (CMAKE_C_STANDARD 11)
    set (CMAKE_CXX_STANDARD 23)
else()
    # Common compilation flags
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wuninitialized -Winit-self -Wmaybe-uninitialized -Warray-bounds -fstack-protector-strong -Wno-deprecated-declarations -fno-strict-overflow -fno-delete-null-pointer-checks -fwrapv")
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wuninitialized -Warray-bounds -fstack-protector-strong -Wno-deprecated-declarations -fno-strict-overflow -fno-delete-null-pointer-checks -fwrapv")

    if(TREAT_WARNING_AS_ERROR)
        set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Werror")
        set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Werror")
    endif()

    # Additional compilation flags aplied to specific targets
    set(C_FLAGS -Wall -Wextra)
    set(CXX_FLAGS -Wall -Wextra)

    set(CMAKE_CXX_FLAGS_RELEASE "-O2")
    if (${CMAKE_SYSTEM_PROCESSOR} STREQUAL "aarch64")
        # TODO: test if it increases x86 performance as well and rm check for aarch64
        set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -ftree-vectorize") # should be used with "-O2"
    endif()

    ## to use C11/C++17
    set (CMAKE_C_STANDARD 11)
    set (CMAKE_CXX_STANDARD 23)
    set (CMAKE_POSITION_INDEPENDENT_CODE ON)

    if (CMAKE_BUILD_TYPE STREQUAL "Release")
        set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wformat -Wformat-security -Werror=format-security -z noexecstack -fPIE -pie -fPIC -D_FORTIFY_SOURCE=2 -Wl,-z,relro,-z,now -fstack-protector-strong")
        set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wformat -Wformat-security -Werror=format-security -z noexecstack -fPIE -pie -fPIC -D_FORTIFY_SOURCE=2 -Wl,-z,relro,-z,now -fstack-protector-strong")
    else()
        set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wformat -Wformat-security -fPIE -pie -fPIC -D_FORTIFY_SOURCE=2 -fstack-protector")
        set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wformat -Wformat-security -fPIE -pie -fPIC -D_FORTIFY_SOURCE=2 -fstack-protector")
    endif()

endif()

if(${ENABLE_AUDIO_INFERENCE_ELEMENTS})
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -DAUDIO ")
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -DAUDIO ")
endif()

# Create config file

configure_file(cmake/config.h.in configs/config.h @ONLY)
include_directories(${CMAKE_CURRENT_BINARY_DIR}/configs)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -DHAVE_CONFIG_H")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -DHAVE_CONFIG_H")


# Find common packages

find_package(Threads REQUIRED)
find_package(PkgConfig REQUIRED)

set(_DLSTREAMER_GST_PKGCONFIG_DIR "${CMAKE_BINARY_DIR}/deps/gstreamer-bin/lib/pkgconfig")
if(EXISTS "${_DLSTREAMER_GST_PKGCONFIG_DIR}/gstreamer-1.0.pc")
    if(DEFINED ENV{PKG_CONFIG_PATH} AND NOT "$ENV{PKG_CONFIG_PATH}" STREQUAL "")
        set(ENV{PKG_CONFIG_PATH} "${_DLSTREAMER_GST_PKGCONFIG_DIR}:$ENV{PKG_CONFIG_PATH}")
    else()
        set(ENV{PKG_CONFIG_PATH} "${_DLSTREAMER_GST_PKGCONFIG_DIR}")
    endif()
    message(STATUS "Using bundled GStreamer pkg-config from ${_DLSTREAMER_GST_PKGCONFIG_DIR}")
endif()

pkg_check_modules(GSTREAMER gstreamer-1.0>=1.16 REQUIRED)
link_directories(${GSTREAMER_LIBRARY_DIRS})

# Add subdirectories

add_subdirectory(include/dlstreamer)
add_subdirectory(include/dlstreamer/gst/videoanalytics)
add_subdirectory(src)
add_subdirectory(src/monolithic)
add_subdirectory(thirdparty)
add_subdirectory(python)

if(${ENABLE_SAMPLES})
    add_subdirectory(samples/gstreamer)
    #add_subdirectory(samples/ffmpeg_openvino/cpp/decode_inference)
    #add_subdirectory(samples/ffmpeg_openvino/cpp/decode_resize_inference)
    #add_subdirectory(samples/ffmpeg_dpcpp/rgb_to_grayscale)
endif()

if(${ENABLE_TESTS} AND NOT(WIN32))
    enable_testing()
    add_subdirectory(tests)
endif()
