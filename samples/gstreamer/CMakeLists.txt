# ==============================================================================
# Copyright (C) 2018-2025 Intel Corporation
#
# SPDX-License-Identifier: MIT
# ==============================================================================

if(TARGET frame_inference)
        add_subdirectory(cpp/draw_face_attributes)
else()
        message(STATUS "Skipping samples/gstreamer/cpp/draw_face_attributes because frame_inference target is unavailable")
endif()

if(NOT(WIN32))
add_custom_target(copy_model_proc ALL)
add_custom_command(TARGET copy_model_proc POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_directory
        ${CMAKE_CURRENT_SOURCE_DIR}/model_proc ${CMAKE_SAMPLES_OUTPUT_DIRECTORY}/model_proc)

install(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/ DESTINATION samples USE_SOURCE_PERMISSIONS PATTERN "cpp" EXCLUDE PATTERN "CMakeLists.txt" EXCLUDE)
# Separate install because 'cpp' folder contains CMakeLists.txt which we ignored in above command
install(DIRECTORY cpp DESTINATION samples USE_SOURCE_PERMISSIONS)
endif()
