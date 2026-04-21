# ==============================================================================
# Copyright (C) 2018-2026 Intel Corporation
#
# SPDX-License-Identifier: MIT
# ==============================================================================

.DEFAULT_GOAL := help
SHELL := /bin/bash

PROJECT_DIRECTORY 			:= ${CURDIR}
DLSTREAMER_INSTALL_PREFIX 	?= /opt/intel/dlstreamer
DEPENDENCY_DIR				:= build/deps
OPENVINO_DIR 				?= /opt/intel/openvino_2026

DLSTREAMER_VERSION 	:= 0.0.0
BUILD_TYPE 			?= Release
ENABLE_GENAI        := OFF
ENABLE_RISCV       ?= ON

RISCV_TOOLCHAIN_FILE ?= ${PROJECT_DIRECTORY}/cmake/toolchains/riscv-vsi.cmake
RISCV_BUILD_DIR      ?= build-riscv
RISCV_DEPENDENCY_DIR ?= ${RISCV_BUILD_DIR}/deps
RISCV_MAIN_BUILD_DIR ?= ${RISCV_BUILD_DIR}/main
RISCV_TOOLCHAIN_ROOT ?= /opt/dlstreamer/riscv/toolchain
RISCV_SYSROOT        ?= /opt/dlstreamer/riscv/sysroot

RISCV_CMAKE_PREFIX_PATH ?= ${PROJECT_DIRECTORY}/${RISCV_DEPENDENCY_DIR}/install;${PROJECT_DIRECTORY}/${RISCV_DEPENDENCY_DIR}/gstreamer-bin;${PROJECT_DIRECTORY}/${RISCV_DEPENDENCY_DIR}/opencv-bin;${PROJECT_DIRECTORY}/${RISCV_DEPENDENCY_DIR}/rdkafka-bin
RISCV_CMAKE_INCLUDE_PATH ?= ${PROJECT_DIRECTORY}/${RISCV_DEPENDENCY_DIR}/install/include:${PROJECT_DIRECTORY}/${RISCV_DEPENDENCY_DIR}/gstreamer-bin/include:${PROJECT_DIRECTORY}/${RISCV_DEPENDENCY_DIR}/rdkafka-bin/include
RISCV_CMAKE_LIBRARY_PATH ?= ${PROJECT_DIRECTORY}/${RISCV_DEPENDENCY_DIR}/install/lib:${PROJECT_DIRECTORY}/${RISCV_DEPENDENCY_DIR}/gstreamer-bin/lib:${PROJECT_DIRECTORY}/${RISCV_DEPENDENCY_DIR}/rdkafka-bin/lib
RISCV_BUILD_JOBS ?= 1

RISCV_HTTP_PROXY_RAW ?= $(or ${http_proxy},${HTTP_PROXY})
RISCV_HTTPS_PROXY_RAW ?= $(or ${https_proxy},${HTTPS_PROXY})
RISCV_HTTP_PROXY ?= $(patsubst https://%,http://%,${RISCV_HTTP_PROXY_RAW})
RISCV_HTTPS_PROXY ?= $(patsubst https://%,http://%,${RISCV_HTTPS_PROXY_RAW})

DOCKER_PRIVATE_REGISTRY := # Empty on purpose

LINUX_DISTRIBUTION := $(shell lsb_release -ds | cut -d " " -f1)
GENAI_DIR_SET := $(shell if [ -n "$$OpenVINOGenAI_DIR" ]; then echo true; else echo false; fi)
ifeq ($(LINUX_DISTRIBUTION), Ubuntu)
ifeq ($(GENAI_DIR_SET), true)
	ENABLE_GENAI := ON
endif
endif

export PATH 					:= ${PROJECT_DIRECTORY}/${DEPENDENCY_DIR}/install/bin:${PROJECT_DIRECTORY}/build/intel64/${BUILD_TYPE}/bin:${HOME}/.local/bin:${HOME}/python3venv/bin:${PATH}
export GST_PLUGIN_PATH 			:= ${PROJECT_DIRECTORY}/${DEPENDENCY_DIR}/gstreamer-bin/lib/gstreamer-1.0:${PROJECT_DIRECTORY}/build/intel64/${BUILD_TYPE}/lib:/usr/lib/x86_64-linux-gnu/gstreamer-1.0
export LIBRARY_PATH 			:= ${PROJECT_DIRECTORY}/${DEPENDENCY_DIR}/install/lib:${PROJECT_DIRECTORY}/${DEPENDENCY_DIR}/gstreamer-bin/lib:${PROJECT_DIRECTORY}/${DEPENDENCY_DIR}/opencv-bin/lib:${PROJECT_DIRECTORY}/${DEPENDENCY_DIR}/rdkafka-bin/lib:${PROJECT_DIRECTORY}/build/intel64/${BUILD_TYPE}/lib:/usr/lib
export PKG_CONFIG_PATH 			:= ${PROJECT_DIRECTORY}/${DEPENDENCY_DIR}/install/lib/pkgconfig:${PROJECT_DIRECTORY}/${DEPENDENCY_DIR}/gstreamer-bin/lib/pkgconfig:${PROJECT_DIRECTORY}/${DEPENDENCY_DIR}/rdkafka-bin/lib/pkgconfig:${PROJECT_DIRECTORY}/build/intel64/${BUILD_TYPE}/lib/pkgconfig:/usr/local/lib/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig
export LIBVA_DRIVER_NAME 		:= iHD
export LIBVA_DRIVERS_PATH 		:= /usr/lib/x86_64-linux-gnu/dri
export GST_VA_ALL_DRIVERS 		:= 1
export GST_PLUGIN_FEATURE_RANK 	:= ${GST_PLUGIN_FEATURE_RANK},ximagesink:MAX
export BUILD_GIRS 				?= OFF


.PHONY: dependencies
dependencies:
	@if [ ! -f build/deps/.deps_built ]; then \
		echo "Building dependencies..."; \
		cmake \
			-B build/deps \
			-DCMAKE_BUILD_TYPE=${BUILD_TYPE} \
			./dependencies; \
		cmake --build build/deps -j$(shell nproc); \
		touch build/deps/.deps_built; \
	else \
		echo "Dependencies already built, skipping..."; \
	fi

.PHONY: build
build: dependencies ## Compile Deep Learning Streamer
	cmake \
		-B build \
		-DCMAKE_PREFIX_PATH:PATH="${PROJECT_DIRECTORY}/${DEPENDENCY_DIR}/install;${PROJECT_DIRECTORY}/${DEPENDENCY_DIR}/opencv-bin;${PROJECT_DIRECTORY}/${DEPENDENCY_DIR}/rdkafka-bin" \
		-DCMAKE_INCLUDE_PATH:PATH=${PROJECT_DIRECTORY}/${DEPENDENCY_DIR}/install/include:${PROJECT_DIRECTORY}/${DEPENDENCY_DIR}/rdkafka-bin/include \
		-DCMAKE_LIBRARY_PATH:PATH=${PROJECT_DIRECTORY}/${DEPENDENCY_DIR}/install/lib \
		-DCMAKE_CXX_FLAGS="-I${PROJECT_DIRECTORY}/${DEPENDENCY_DIR}/rdkafka-bin/include" \
		-DCMAKE_BUILD_TYPE=${BUILD_TYPE} \
		-DENABLE_PAHO_INSTALLATION=ON \
		-DENABLE_RDKAFKA_INSTALLATION=ON \
		-DENABLE_VAAPI=OFF \
		-DENABLE_RISCV=${ENABLE_RISCV} \
		-DENABLE_SAMPLES=ON \
		-DENABLE_GENAI=${ENABLE_GENAI} \
		-DGENERATE_GIR_FROM_SOURCE=${BUILD_GIRS} \
		-DENABLE_TESTS=OFF; \
	cmake --build build -j$(shell nproc)

.PHONY: dependencies-riscv
dependencies-riscv: riscv-sysroot-fixups ## Build dependencies with RISC-V toolchain
	@rm -f ${RISCV_DEPENDENCY_DIR}/CMakeCache.txt
	@rm -rf ${RISCV_DEPENDENCY_DIR}/CMakeFiles
	HTTP_PROXY=${RISCV_HTTP_PROXY} HTTPS_PROXY=${RISCV_HTTPS_PROXY} \
	http_proxy=${RISCV_HTTP_PROXY} https_proxy=${RISCV_HTTPS_PROXY} \
	PKG_CONFIG_PATH= \
	LIBRARY_PATH=${PROJECT_DIRECTORY}/${RISCV_DEPENDENCY_DIR}/install/lib:${PROJECT_DIRECTORY}/${RISCV_DEPENDENCY_DIR}/gstreamer-bin/lib:${PROJECT_DIRECTORY}/${RISCV_DEPENDENCY_DIR}/opencv-bin/lib:${PROJECT_DIRECTORY}/${RISCV_DEPENDENCY_DIR}/rdkafka-bin/lib \
	cmake \
		-B ${RISCV_DEPENDENCY_DIR} \
		-DCMAKE_BUILD_TYPE=${BUILD_TYPE} \
		-DCMAKE_TOOLCHAIN_FILE=${RISCV_TOOLCHAIN_FILE} \
		-DRISCV_TOOLCHAIN_ROOT=${RISCV_TOOLCHAIN_ROOT} \
		-DRISCV_SYSROOT=${RISCV_SYSROOT} \
		./dependencies
	HTTP_PROXY=${RISCV_HTTP_PROXY} HTTPS_PROXY=${RISCV_HTTPS_PROXY} \
	http_proxy=${RISCV_HTTP_PROXY} https_proxy=${RISCV_HTTPS_PROXY} \
	PKG_CONFIG_PATH= \
	LIBRARY_PATH=${PROJECT_DIRECTORY}/${RISCV_DEPENDENCY_DIR}/install/lib:${PROJECT_DIRECTORY}/${RISCV_DEPENDENCY_DIR}/gstreamer-bin/lib:${PROJECT_DIRECTORY}/${RISCV_DEPENDENCY_DIR}/opencv-bin/lib:${PROJECT_DIRECTORY}/${RISCV_DEPENDENCY_DIR}/rdkafka-bin/lib \
	cmake --build ${RISCV_DEPENDENCY_DIR} -j${RISCV_BUILD_JOBS}

.PHONY: riscv-sysroot-fixups
riscv-sysroot-fixups: ## Ensure required unversioned symlinks exist in RISC-V sysroot
	@set -e; \
	sysroot="${RISCV_SYSROOT}"; \
	if [ ! -d "$$sysroot" ]; then \
		echo "RISC-V sysroot not found, skip fixups: $$sysroot"; \
		exit 0; \
	fi; \
	fix_link() { \
		base="$$1"; \
		for dir in "$$sysroot/usr/lib/riscv64-linux-gnu" "$$sysroot/lib/riscv64-linux-gnu" "$$sysroot/usr/lib" "$$sysroot/lib"; do \
			if [ ! -d "$$dir" ]; then \
				continue; \
			fi; \
			if [ -e "$$dir/$$base" ]; then \
				return 0; \
			fi; \
			cand=$$(find "$$dir" -maxdepth 1 -type f -name "$$base.*" | sort | head -n 1); \
			if [ -n "$$cand" ]; then \
				ln -sfn "$$(basename "$$cand")" "$$dir/$$base"; \
				echo "Created symlink: $$dir/$$base -> $$(basename "$$cand")"; \
				return 0; \
			fi; \
		done; \
	}; \
	fix_link libva.so; \
	fix_link libva-drm.so; \
	fix_link libXv.so; \
	fix_link libGL.so; \
	fix_link libdl.so; \
	fix_link libgstva-1.0.so; \
	fix_link libgstanalytics-1.0.so; \
	if [ ! -f "$$sysroot/usr/include/va/va.h" ] && [ -f "/usr/include/va/va.h" ]; then \
		mkdir -p "$$sysroot/usr/include"; \
		rm -rf "$$sysroot/usr/include/va"; \
		cp -a /usr/include/va "$$sysroot/usr/include/"; \
		echo "Staged VA headers into sysroot: $$sysroot/usr/include/va"; \
	fi

.PHONY: build-riscv
build-riscv: dependencies-riscv ## Cross-compile Deep Learning Streamer for RISC-V
	@rm -rf ${RISCV_MAIN_BUILD_DIR}
	HTTP_PROXY=${RISCV_HTTP_PROXY} HTTPS_PROXY=${RISCV_HTTPS_PROXY} \
	http_proxy=${RISCV_HTTP_PROXY} https_proxy=${RISCV_HTTPS_PROXY} \
	PKG_CONFIG_PATH= \
	LIBRARY_PATH=${PROJECT_DIRECTORY}/${RISCV_DEPENDENCY_DIR}/install/lib:${PROJECT_DIRECTORY}/${RISCV_DEPENDENCY_DIR}/gstreamer-bin/lib:${PROJECT_DIRECTORY}/${RISCV_DEPENDENCY_DIR}/opencv-bin/lib:${PROJECT_DIRECTORY}/${RISCV_DEPENDENCY_DIR}/rdkafka-bin/lib \
	cmake \
		-B ${RISCV_MAIN_BUILD_DIR} \
		-DCMAKE_TOOLCHAIN_FILE=${RISCV_TOOLCHAIN_FILE} \
		-DRISCV_TOOLCHAIN_ROOT=${RISCV_TOOLCHAIN_ROOT} \
		-DRISCV_SYSROOT=${RISCV_SYSROOT} \
		-DENABLE_RISCV=ON \
		-DPKG_CONFIG_USE_CMAKE_PREFIX_PATH=OFF \
		-DCMAKE_PREFIX_PATH:PATH="${RISCV_CMAKE_PREFIX_PATH}" \
		-DCMAKE_INCLUDE_PATH:PATH=${RISCV_CMAKE_INCLUDE_PATH} \
		-DCMAKE_LIBRARY_PATH:PATH=${RISCV_CMAKE_LIBRARY_PATH} \
		-DCMAKE_BUILD_TYPE=${BUILD_TYPE} \
		-DENABLE_PAHO_INSTALLATION=ON \
		-DENABLE_RDKAFKA_INSTALLATION=ON \
		-DENABLE_VAAPI=OFF \
		-DENABLE_SAMPLES=ON \
		-DENABLE_OPENVINO=OFF \
		-DENABLE_GST_ANALYTICS=ON \
		-DENABLE_ITT=ON \
		-DENABLE_GENAI=${ENABLE_GENAI} \
		-DENABLE_TESTS=OFF; \
	HTTP_PROXY=${RISCV_HTTP_PROXY} HTTPS_PROXY=${RISCV_HTTPS_PROXY} \
	http_proxy=${RISCV_HTTP_PROXY} https_proxy=${RISCV_HTTPS_PROXY} \
	PKG_CONFIG_PATH= \
	LIBRARY_PATH=${PROJECT_DIRECTORY}/${RISCV_DEPENDENCY_DIR}/install/lib:${PROJECT_DIRECTORY}/${RISCV_DEPENDENCY_DIR}/gstreamer-bin/lib:${PROJECT_DIRECTORY}/${RISCV_DEPENDENCY_DIR}/opencv-bin/lib:${PROJECT_DIRECTORY}/${RISCV_DEPENDENCY_DIR}/rdkafka-bin/lib \
	cmake --build ${RISCV_MAIN_BUILD_DIR} -j${RISCV_BUILD_JOBS}

.PHONY: install
install: build ## Build and install Deep Learning Streamer
	@echo "Installing Deep Learning Streamer"
	@mkdir -p ${DLSTREAMER_INSTALL_PREFIX}
	@rm -rf ${DLSTREAMER_INSTALL_PREFIX}/*
	@if [ -f build/deps/.deps_built ]; then \
		echo "Installing dependencies..."; \
		cmake \
			-B build/deps \
			-DCMAKE_BUILD_TYPE=${BUILD_TYPE} \
			-DINSTALL_DLSTREAMER=True \
			-DDLSTREAMER_INSTALL_PREFIX=${DLSTREAMER_INSTALL_PREFIX} \
			./dependencies; \
	fi
	@cp -r build/intel64/${BUILD_TYPE} ${DLSTREAMER_INSTALL_PREFIX}
	@cp -r samples/ ${DLSTREAMER_INSTALL_PREFIX}
	@cp -r python/ ${DLSTREAMER_INSTALL_PREFIX}
	@cp -r scripts/ ${DLSTREAMER_INSTALL_PREFIX}
	@cp -r include/ ${DLSTREAMER_INSTALL_PREFIX}
	@cp README.md ${DLSTREAMER_INSTALL_PREFIX}
	@mkdir -p ${DLSTREAMER_INSTALL_PREFIX}/lib/girepository-1.0
	@if [ -f build/src/gst/metadata/DLStreamerMeta-1.0.typelib ]; then \
		echo "Installing typelib file..."; \
		cp build/src/gst/metadata/DLStreamerMeta-1.0.typelib ${DLSTREAMER_INSTALL_PREFIX}/lib/girepository-1.0/; \
	fi
	@echo "Installation successful"

.PHONY: deb
deb: ## Build the Deep Learning Streamer DEB package for Ubuntu 24.04
	mkdir -p build/packages/deb
	docker build . \
		-f docker/ubuntu/ubuntu24.Dockerfile \
		-t deb-builder \
		--target deb-builder \
		--build-arg http_proxy=${http_proxy} \
		--build-arg https_proxy=${https_proxy} \
		--build-arg DLSTREAMER_VERSION=${DLSTREAMER_VERSION} \
		--build-arg DLSTREAMER_BUILD_NUMBER=1 \
		--build-arg DEV_MODE=true \
		--build-arg DOCKER_PRIVATE_REGISTRY=${DOCKER_PRIVATE_REGISTRY}
	docker create \
		--name deb-builder \
		deb-builder
	docker cp deb-builder:/intel-dlstreamer_${DLSTREAMER_VERSION}.1_amd64.deb ./build/packages/deb
	docker rm deb-builder

.PHONY: deb22
deb22: ## Build the Deep Learning Streamer DEB package for Ubuntu 22.04
	mkdir -p build/packages/deb
	docker build . \
		-f docker/ubuntu/ubuntu22.Dockerfile \
		-t deb-builder \
		--target deb-builder \
		--build-arg http_proxy=${http_proxy} \
		--build-arg https_proxy=${https_proxy} \
		--build-arg DLSTREAMER_VERSION=${DLSTREAMER_VERSION} \
		--build-arg DLSTREAMER_BUILD_NUMBER=1 \
		--build-arg DEV_MODE=true \
		--build-arg DOCKER_PRIVATE_REGISTRY=${DOCKER_PRIVATE_REGISTRY}
	docker create \
		--name deb-builder \
		deb-builder
	docker cp deb-builder:/intel-dlstreamer_${DLSTREAMER_VERSION}.1_amd64.deb ./build/packages/deb
	docker rm deb-builder

.PHONY: rpm
rpm: ## Build the Deep Learning Streamer RPM package
	mkdir -p build/packages/rpm
	docker build . \
		-t rpm-builder \
		-f docker/fedora41/fedora41.Dockerfile \
		--target rpm-builder \
		--build-arg http_proxy=${http_proxy} \
		--build-arg https_proxy=${https_proxy} \
		--build-arg DLSTREAMER_VERSION=${DLSTREAMER_VERSION} \
		--build-arg DLSTREAMER_BUILD_NUMBER=1 \
		--build-arg DEV_MODE=true \
		--build-arg DOCKER_PRIVATE_REGISTRY=${DOCKER_PRIVATE_REGISTRY}
	docker create \
		--name rpm-builder \
		rpm-builder
	docker cp rpm-builder:/intel-dlstreamer-${DLSTREAMER_VERSION}.1-1.fc41.x86_64.rpm ./build/packages/rpm
	docker rm rpm-builder

.PHONY: image
image: ## Build the Deep Learning Streamer docker image based on Ubuntu 24.04
	docker build . \
		-f docker/ubuntu/ubuntu24.Dockerfile \
		-t dlstreamer:dev \
		--target dlstreamer \
		--build-arg http_proxy=${http_proxy} \
		--build-arg https_proxy=${https_proxy} \
		--build-arg DLSTREAMER_VERSION=${DLSTREAMER_VERSION} \
		--build-arg DLSTREAMER_BUILD_NUMBER=1 \
		--build-arg DEV_MODE=true \
		--build-arg DOCKER_PRIVATE_REGISTRY=${DOCKER_PRIVATE_REGISTRY}

.PHONY: image22
image22: ## Build the Deep Learning Streamer docker image based on Ubuntu 22.04
	docker build . \
		-f docker/ubuntu/ubuntu22.Dockerfile \
		-t dlstreamer:dev \
		--target dlstreamer \
		--build-arg http_proxy=${http_proxy} \
		--build-arg https_proxy=${https_proxy} \
		--build-arg DLSTREAMER_VERSION=${DLSTREAMER_VERSION} \
		--build-arg DLSTREAMER_BUILD_NUMBER=1 \
		--build-arg DEV_MODE=true \
		--build-arg DOCKER_PRIVATE_REGISTRY=${DOCKER_PRIVATE_REGISTRY}

.PHONY: clean
clean: ## Cleanup any build artifacts
	@rm -rf build
	@rm -rf ${RISCV_BUILD_DIR}

.PHONY: help
help: ## Display help about the commands
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
