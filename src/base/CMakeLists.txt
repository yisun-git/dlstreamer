# ==============================================================================
# Copyright (C) 2022-2024 Intel Corporation
#
# SPDX-License-Identifier: MIT
# ==============================================================================

add_subdirectory(base_histogram)
add_subdirectory(base_meta_overlay)

add_subdirectory(dlstreamer_logger)

if(ENABLE_OPENVINO)
	add_subdirectory(frame_inference)
	add_subdirectory(openvino_inference_backend)
else()
	message(STATUS "Skipping frame_inference/openvino_inference_backend because ENABLE_OPENVINO=OFF")
endif()