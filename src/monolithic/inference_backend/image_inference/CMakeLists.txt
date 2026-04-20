# ==============================================================================
# Copyright (C) 2018-2026 Intel Corporation
#
# SPDX-License-Identifier: MIT
# ==============================================================================

set (TARGET_NAME "image_inference")

if(NOT ENABLE_RISCV)
        find_package(OpenVINO QUIET COMPONENTS Runtime)
        if(OpenVINO_FOUND)
                add_subdirectory(openvino)
                set(ENABLE_OPENVINO_BACKEND ON)
        else()
                message(STATUS "OpenVINO not found. OpenVINO backend in image_inference will be disabled.")
        endif()
endif()

if(${ENABLE_VAAPI} AND NOT(WIN32))
        add_subdirectory(async_with_va_api)
endif()

if(WIN32)
        add_subdirectory(async_with_d3d11)
endif()

find_package(PkgConfig REQUIRED)

file (GLOB MAIN_SRC
        ${CMAKE_CURRENT_SOURCE_DIR}/*.cpp
        ${CMAKE_CURRENT_SOURCE_DIR}/*.c
        )

file (GLOB MAIN_HEADERS
        ${CMAKE_CURRENT_SOURCE_DIR}/*.h
        )

add_library(${TARGET_NAME} STATIC ${MAIN_SRC} ${MAIN_HEADERS})
set_compile_flags(${TARGET_NAME})

target_include_directories(${TARGET_NAME}
PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}
        ${CMAKE_CURRENT_SOURCE_DIR}/async_with_va_api
)

if (ENABLE_OPENVINO_BACKEND)
        target_include_directories(${TARGET_NAME} PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/openvino)
        target_compile_definitions(${TARGET_NAME} PUBLIC ENABLE_OPENVINO_BACKEND)
endif()

if(WIN32)
        target_include_directories(${TARGET_NAME} PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/async_with_d3d11)
endif()

target_link_libraries(${TARGET_NAME}
PUBLIC
        logger
        utils
)

if (ENABLE_OPENVINO_BACKEND)
        target_link_libraries(${TARGET_NAME} PUBLIC image_inference_openvino openvino::runtime)
endif()

if(NOT ENABLE_OPENVINO_BACKEND)
        message(WARNING "No OpenVINO backend enabled for image_inference. Building image_inference without OpenVINO backend.")
endif()
