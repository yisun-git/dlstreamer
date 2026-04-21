# ==============================================================================
# Copyright (C) 2018 Intel Corporation
#
# SPDX-License-Identifier: MIT
# ==============================================================================

find_package (Threads)

set(TARGET_NAME "ittnotify")

set(_OPENCV_ITT_ROOT ${CMAKE_SOURCE_DIR}/build-riscv/deps/opencv/src/opencv/3rdparty/ittnotify)

if(ENABLE_RISCV AND EXISTS ${_OPENCV_ITT_ROOT}/src/ittnotify/ittnotify_static.c)
	add_library(${TARGET_NAME} STATIC
		${_OPENCV_ITT_ROOT}/src/ittnotify/ittnotify_static.c
		${_OPENCV_ITT_ROOT}/src/ittnotify/jitprofiling.c
	)

	target_include_directories(${TARGET_NAME}
		PUBLIC
			${_OPENCV_ITT_ROOT}/include
			${_OPENCV_ITT_ROOT}/src/ittnotify
	)

	target_link_libraries(${TARGET_NAME}
		PUBLIC
			${CMAKE_DL_LIBS}
			${CMAKE_THREAD_LIBS_INIT}
	)
else()
	add_library(${TARGET_NAME} INTERFACE)

	target_include_directories(${TARGET_NAME} INTERFACE include)
	target_link_libraries(${TARGET_NAME} INTERFACE ${CMAKE_CURRENT_SOURCE_DIR}/lib/libittnotify.a ${CMAKE_DL_LIBS} ${CMAKE_THREAD_LIBS_INIT})
endif()
