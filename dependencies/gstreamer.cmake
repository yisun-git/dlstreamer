# ==============================================================================
# Copyright (C) 2018-2026 Intel Corporation
#
# SPDX-License-Identifier: MIT
# ==============================================================================

include(ExternalProject)
find_package(Python3 REQUIRED COMPONENTS Interpreter)

# When changing version, you will also need to change the download hash
set(DESIRED_VERSION 1.26.6)

set(_GST_MESON_SETUP_ARGS
	--prefix ${CMAKE_BINARY_DIR}/gstreamer-bin
	-Dexamples=disabled
	-Dtests=disabled
	-Dvaapi=enabled
	-Dlibnice=enabled
	-Dgst-examples=disabled
	-Ddevtools=disabled
	-Dorc=disabled
	-Dgpl=disabled
	-Dpython=enabled
	-Dgst-plugins-base:nls=disabled
	-Dgst-plugins-base:gl=disabled
	-Dgst-plugins-base:xvideo=enabled
	-Dgst-plugins-base:vorbis=enabled
	-Dgst-plugins-base:pango=disabled
	-Dgst-plugins-good:nls=disabled
	-Dgst-plugins-good:libcaca=disabled
	-Dgst-plugins-good:vpx=enabled
	-Dgst-plugins-good:rtp=enabled
	-Dgst-plugins-good:rtpmanager=enabled
	-Dgst-plugins-good:adaptivedemux2=disabled
	-Dgst-plugins-good:lame=disabled
	-Dgst-plugins-good:flac=disabled
	-Dgst-plugins-good:dv=disabled
	-Dgst-plugins-good:soup=enabled
	-Dgst-plugins-bad:gpl=disabled
	-Dgst-plugins-bad:va=enabled
	-Dgst-plugins-bad:doc=disabled
	-Dgst-plugins-bad:nls=disabled
	-Dgst-plugins-bad:neon=disabled
	-Dgst-plugins-bad:directfb=disabled
	-Dgst-plugins-bad:openni2=disabled
	-Dgst-plugins-bad:fdkaac=disabled
	-Dgst-plugins-bad:ladspa=disabled
	-Dgst-plugins-bad:assrender=disabled
	-Dgst-plugins-bad:bs2b=disabled
	-Dgst-plugins-bad:flite=disabled
	-Dgst-plugins-bad:rtmp=disabled
	-Dgst-plugins-bad:sbc=disabled
	-Dgst-plugins-bad:teletext=disabled
	-Dgst-plugins-bad:hls-crypto=openssl
	-Dgst-plugins-bad:libde265=enabled
	-Dgst-plugins-bad:openh264=enabled
	-Dgst-plugins-bad:uvch264=enabled
	-Dgst-plugins-bad:x265=disabled
	-Dgst-plugins-bad:curl=enabled
	-Dgst-plugins-bad:curl-ssh2=enabled
	-Dgst-plugins-bad:opus=enabled
	-Dgst-plugins-bad:dtls=enabled
	-Dgst-plugins-bad:srtp=enabled
	-Dgst-plugins-bad:webrtc=enabled
	-Dgst-plugins-bad:webrtcdsp=disabled
	-Dgst-plugins-bad:dash=disabled
	-Dgst-plugins-bad:aja=disabled
	-Dgst-plugins-bad:openjpeg=disabled
	-Dgst-plugins-bad:analyticsoverlay=disabled
	-Dgst-plugins-bad:closedcaption=disabled
	-Dgst-plugins-bad:ttml=disabled
	-Dgst-plugins-bad:codec2json=disabled
	-Dgst-plugins-bad:qroverlay=disabled
	-Dgst-plugins-bad:soundtouch=disabled
	-Dgst-plugins-bad:isac=disabled
	-Dgst-plugins-bad:openexr=disabled
	-Dgst-plugins-bad:wayland=enabled
	-Dgstreamer-vaapi:glx=enabled
	-Dgstreamer-vaapi:wayland=enabled
	-Dgst-plugins-ugly:nls=disabled
	-Dgst-plugins-ugly:x264=disabled
	-Dgst-plugins-ugly:gpl=disabled
	--buildtype=release
	--libdir=lib/
	--libexecdir=bin/
)

set(_GST_MESON_CMD meson)
execute_process(
	COMMAND "${Python3_EXECUTABLE}" -c "import mesonbuild.mesonmain"
	RESULT_VARIABLE _GST_PY_MESON_RESULT
	OUTPUT_QUIET
	ERROR_QUIET
)
if(_GST_PY_MESON_RESULT EQUAL 0)
	set(_GST_MESON_CMD "${Python3_EXECUTABLE}" -m mesonbuild.mesonmain)
endif()

set(_GST_CONFIGURE_COMMAND ${_GST_MESON_CMD} setup ${_GST_MESON_SETUP_ARGS} <SOURCE_DIR>)
set(_GST_BUILD_COMMAND ninja)
set(_GST_INSTALL_COMMAND ${_GST_MESON_CMD} install)
set(_GST_GIT_CONFIG)

if(DEFINED ENV{HTTP_PROXY} AND NOT "$ENV{HTTP_PROXY}" STREQUAL "")
	list(APPEND _GST_GIT_CONFIG "http.proxy=$ENV{HTTP_PROXY}")
endif()
if(DEFINED ENV{HTTPS_PROXY} AND NOT "$ENV{HTTPS_PROXY}" STREQUAL "")
	list(APPEND _GST_GIT_CONFIG "https.proxy=$ENV{HTTPS_PROXY}")
endif()

if(CMAKE_CROSSCOMPILING)
	# Keep Python and introspection enabled for cross builds.
	# gst-python in gstreamer-full requires introspection support.
	list(APPEND _GST_MESON_SETUP_ARGS
		-Dpython=enabled
		-Dintrospection=enabled
		-Dpygobject:pycairo=disabled
		-Dpygobject:tests=false
	)

	# Keep display and vaapi-related paths enabled for cross builds.
	list(REMOVE_ITEM _GST_MESON_SETUP_ARGS
		-Dgst-plugins-base:xvideo=disabled
		-Dgst-plugins-bad:va=disabled
		-Dgst-plugins-bad:wayland=disabled
		-Dgstreamer-vaapi:glx=disabled
		-Dgstreamer-vaapi:wayland=disabled
	)
	list(APPEND _GST_MESON_SETUP_ARGS
		-Dgst-plugins-base:xvideo=enabled
		-Dgst-plugins-bad:va=enabled
		-Dgst-plugins-bad:wayland=enabled
		-Dgstreamer-vaapi:glx=enabled
		-Dgstreamer-vaapi:wayland=enabled
	)

	# Keep non-x86 plugin families enabled for RISC-V cross builds.
	# x86/GPU-platform-dependent plugins remain disabled below.
	list(REMOVE_ITEM _GST_MESON_SETUP_ARGS
		-Dlibnice=enabled
		-Dgst-plugins-good:soup=enabled
		-Dgst-plugins-bad:dtls=enabled
		-Dgst-plugins-bad:srtp=enabled
		-Dgst-plugins-bad:webrtc=enabled
		-Dgst-plugins-bad:uvch264=enabled
		-Dgst-plugins-bad:curl=enabled
		-Dgst-plugins-bad:curl-ssh2=enabled
		-Dgst-plugins-bad:qsv=enabled
	)
	list(APPEND _GST_MESON_SETUP_ARGS
		-Dlibnice=enabled
		-Dgst-plugins-good:soup=enabled
		-Dgst-plugins-bad:dtls=enabled
		-Dgst-plugins-bad:srtp=enabled
		-Dgst-plugins-bad:webrtc=enabled
		-Dgst-plugins-bad:uvch264=enabled
		-Dgst-plugins-bad:nvcodec=disabled
		-Dgst-plugins-bad:curl=enabled
		-Dgst-plugins-bad:curl-ssh2=enabled
		-Dgst-plugins-bad:qsv=disabled
	)

	set(_GST_MESON_CROSS_FILE "${CMAKE_BINARY_DIR}/gstreamer-meson-cross.ini")
	if(DEFINED RISCV_ARCH_ABI_FLAGS AND NOT "${RISCV_ARCH_ABI_FLAGS}" STREQUAL "")
		separate_arguments(_GST_RISCV_ABI_ARGS NATIVE_COMMAND "${RISCV_ARCH_ABI_FLAGS}")
	else()
		set(_GST_RISCV_ABI_ARGS -march=rv64imafdc -mabi=lp64d)
	endif()
	string(JOIN " " _GST_RISCV_ABI_FLAGS_STR ${_GST_RISCV_ABI_ARGS})

	set(_GST_MESON_COMPILE_ARGS)
	set(_GST_MESON_LINK_ARGS)
	set(_GST_INCLUDE_OVERRIDE_DIR)
	if(DEFINED RISCV_INCLUDE_OVERRIDE_DIR AND EXISTS "${RISCV_INCLUDE_OVERRIDE_DIR}")
		set(_GST_INCLUDE_OVERRIDE_DIR "${RISCV_INCLUDE_OVERRIDE_DIR}")
	elseif(EXISTS "${CMAKE_BINARY_DIR}/riscv-include-overrides")
		set(_GST_INCLUDE_OVERRIDE_DIR "${CMAKE_BINARY_DIR}/riscv-include-overrides")
	endif()
	foreach(_arg IN LISTS _GST_RISCV_ABI_ARGS)
		string(APPEND _GST_MESON_COMPILE_ARGS "'${_arg}',")
		string(APPEND _GST_MESON_LINK_ARGS "'${_arg}',")
	endforeach()
	if(CMAKE_SYSROOT)
		string(APPEND _GST_MESON_COMPILE_ARGS "'--sysroot=${CMAKE_SYSROOT}',")
		if(_GST_INCLUDE_OVERRIDE_DIR)
			string(APPEND _GST_MESON_COMPILE_ARGS "'-isystem${_GST_INCLUDE_OVERRIDE_DIR}',")
		endif()
		string(APPEND _GST_MESON_COMPILE_ARGS "'-isystem${CMAKE_SYSROOT}/usr/include/riscv64-linux-gnu',")

		string(APPEND _GST_MESON_LINK_ARGS "'--sysroot=${CMAKE_SYSROOT}',")
		string(APPEND _GST_MESON_LINK_ARGS "'-L${CMAKE_SYSROOT}/usr/lib',")
		string(APPEND _GST_MESON_LINK_ARGS "'-lGLX',")
		string(APPEND _GST_MESON_LINK_ARGS "'-B${CMAKE_SYSROOT}/usr/lib/riscv64-linux-gnu',")
		string(APPEND _GST_MESON_LINK_ARGS "'-B${CMAKE_SYSROOT}/lib/riscv64-linux-gnu',")
		string(APPEND _GST_MESON_LINK_ARGS "'-L${CMAKE_SYSROOT}/usr/lib/riscv64-linux-gnu',")
		string(APPEND _GST_MESON_LINK_ARGS "'-L${CMAKE_SYSROOT}/lib/riscv64-linux-gnu',")
		string(APPEND _GST_MESON_LINK_ARGS "'-Wl,-rpath-link,${CMAKE_SYSROOT}/usr/lib',")
		string(APPEND _GST_MESON_LINK_ARGS "'-Wl,-rpath-link,${CMAKE_SYSROOT}/usr/lib/riscv64-linux-gnu',")
		string(APPEND _GST_MESON_LINK_ARGS "'-Wl,-rpath-link,${CMAKE_SYSROOT}/lib/riscv64-linux-gnu',")
	endif()
	string(REGEX REPLACE ",$" "" _GST_MESON_COMPILE_ARGS "${_GST_MESON_COMPILE_ARGS}")
	string(REGEX REPLACE ",$" "" _GST_MESON_LINK_ARGS "${_GST_MESON_LINK_ARGS}")
	if(CMAKE_C_COMPILER_TARGET)
		set(_GST_HOST_TRIPLET "${CMAKE_C_COMPILER_TARGET}")
	else()
		set(_GST_HOST_TRIPLET "riscv64-linux-gnu")
	endif()

	if(CMAKE_C_COMPILER_AR)
		set(_GST_AR_ENTRY "ar = '${CMAKE_C_COMPILER_AR}'\n")
	else()
		set(_GST_AR_ENTRY "")
	endif()
	if(CMAKE_C_COMPILER_RANLIB)
		set(_GST_RANLIB_ENTRY "ranlib = '${CMAKE_C_COMPILER_RANLIB}'\n")
	else()
		set(_GST_RANLIB_ENTRY "")
	endif()

	set(_GST_PKG_CONFIG_LIBDIR "$ENV{PKG_CONFIG_LIBDIR}")
	if(NOT _GST_PKG_CONFIG_LIBDIR)
		set(_GST_PKG_CONFIG_LIBDIR
			"${CMAKE_SYSROOT}/usr/lib/pkgconfig:${CMAKE_SYSROOT}/usr/share/pkgconfig:${CMAKE_SYSROOT}/usr/lib/riscv64-linux-gnu/pkgconfig:${CMAKE_SYSROOT}/lib/riscv64-linux-gnu/pkgconfig"
		)
	endif()

	set(_GST_PKG_CONFIG_WRAPPER "${CMAKE_BINARY_DIR}/gstreamer-pkg-config-wrapper.sh")
	file(WRITE "${_GST_PKG_CONFIG_WRAPPER}"
"#!/usr/bin/env bash\n"
"set -e\n"
"_var_name=\"\"\n"
"for _tok in \"$@\"; do\n"
"  case \"$_tok\" in\n"
"    --variable=*) _var_name=\"\${_tok#--variable=}\" ;;\n"
"  esac\n"
"done\n"
	"if [[ \"$_var_name\" == \"glib_compile_resources\" ]]; then\n"
"  echo /usr/bin/glib-compile-resources\n"
"  exit 0\n"
"fi\n"
	"if [[ \"$_var_name\" == \"g_ir_compiler\" ]]; then\n"
"  echo ${CMAKE_BINARY_DIR}/riscv64-linux-gnu-g-ir-compiler\n"
"  exit 0\n"
"fi\n"
	"if [[ \"$_var_name\" == \"glib_mkenums\" ]]; then\n"
"  echo /usr/bin/glib-mkenums\n"
"  exit 0\n"
"fi\n"
	"if [[ \"$_var_name\" == \"glib_genmarshal\" ]]; then\n"
"  echo /usr/bin/glib-genmarshal\n"
"  exit 0\n"
"fi\n"
	"if [[ \"$_var_name\" == \"gobject_query\" ]]; then\n"
"  echo /usr/bin/gobject-query\n"
"  exit 0\n"
"fi\n"
"export PKG_CONFIG_SYSROOT_DIR='${CMAKE_SYSROOT}'\n"
"export PKG_CONFIG_LIBDIR='${_GST_PKG_CONFIG_LIBDIR}'\n"
"export PKG_CONFIG_PATH=\n"
"_args=()\n"
"for _arg in \"$@\"; do\n"
"  case \"$_arg\" in\n"
"    python-[0-9]*.[0-9]*-embed) _args+=(python3-embed) ;;\n"
"    python-[0-9]*.[0-9]*) _args+=(python3) ;;\n"
"    *) _args+=(\"$_arg\") ;;\n"
"  esac\n"
"done\n"
"exec pkg-config \"\${_args[@]}\"\n"
)
	file(CHMOD "${_GST_PKG_CONFIG_WRAPPER}"
		PERMISSIONS
			OWNER_READ OWNER_WRITE OWNER_EXECUTE
			GROUP_READ GROUP_EXECUTE
			WORLD_READ WORLD_EXECUTE
	)

	set(_GST_EXE_WRAPPER "${CMAKE_BINARY_DIR}/riscv64-linux-gnu-cross-exe-wrapper")
	file(WRITE "${_GST_EXE_WRAPPER}"
"#!/usr/bin/env bash\n"
"set -e\n"
"if [[ $# -lt 1 ]]; then\n"
"  echo 'ERROR: cross-exe-wrapper expects a target executable path' >&2\n"
"  exit 2\n"
"fi\n"
"_exe=\"$1\"\n"
"shift\n"
"if [[ \"$_exe\" == /* && ! -e \"$_exe\" && -e \"${CMAKE_SYSROOT}\$_exe\" ]]; then\n"
"  _exe=\"${CMAKE_SYSROOT}\$_exe\"\n"
"fi\n"
"if command -v qemu-riscv64-static >/dev/null 2>&1; then\n"
"  exec qemu-riscv64-static -L '${CMAKE_SYSROOT}' \"$_exe\" \"$@\"\n"
"fi\n"
"if command -v qemu-riscv64 >/dev/null 2>&1; then\n"
"  exec qemu-riscv64 -L '${CMAKE_SYSROOT}' \"$_exe\" \"$@\"\n"
"fi\n"
"echo 'ERROR: qemu-riscv64-static/qemu-riscv64 not found in PATH for cross executable wrapper' >&2\n"
"exit 127\n"
)
	file(CHMOD "${_GST_EXE_WRAPPER}"
		PERMISSIONS
			OWNER_READ OWNER_WRITE OWNER_EXECUTE
			GROUP_READ GROUP_EXECUTE
			WORLD_READ WORLD_EXECUTE
	)

	set(_GST_GIR_COMPILER_WRAPPER "${CMAKE_BINARY_DIR}/riscv64-linux-gnu-g-ir-compiler")
	file(WRITE "${_GST_GIR_COMPILER_WRAPPER}"
"#!/usr/bin/env bash\n"
"set -e\n"
"exec ${_GST_EXE_WRAPPER} ${CMAKE_SYSROOT}/usr/lib/riscv64-linux-gnu/gobject-introspection/g-ir-compiler \"$@\"\n"
)
	file(CHMOD "${_GST_GIR_COMPILER_WRAPPER}"
		PERMISSIONS
			OWNER_READ OWNER_WRITE OWNER_EXECUTE
			GROUP_READ GROUP_EXECUTE
			WORLD_READ WORLD_EXECUTE
	)

	set(_GST_CC_WRAPPER "${CMAKE_BINARY_DIR}/gstreamer-cc-wrapper.sh")
	file(WRITE "${_GST_CC_WRAPPER}"
"#!/usr/bin/env bash\n"
"set -e\n"
"extra_args=(${_GST_RISCV_ABI_FLAGS_STR})\n"
"extra_args+=(--sysroot=${CMAKE_SYSROOT})\n"
"extra_args+=(-L${CMAKE_SYSROOT}/usr/lib)\n"
"extra_args+=(-lGLX)\n"
"extra_args+=(-B${CMAKE_SYSROOT}/usr/lib/riscv64-linux-gnu)\n"
"extra_args+=(-B${CMAKE_SYSROOT}/lib/riscv64-linux-gnu)\n"
	"extra_args+=(-I${CMAKE_SYSROOT}/usr/include/riscv64-linux-gnu)\n"
"extra_args+=(-L${CMAKE_SYSROOT}/usr/lib/riscv64-linux-gnu)\n"
"extra_args+=(-L${CMAKE_SYSROOT}/lib/riscv64-linux-gnu)\n"
"extra_args+=(-Wl,-rpath-link,${CMAKE_SYSROOT}/usr/lib)\n"
"extra_args+=(-Wl,-rpath-link,${CMAKE_SYSROOT}/usr/lib/riscv64-linux-gnu)\n"
"extra_args+=(-Wl,-rpath-link,${CMAKE_SYSROOT}/lib/riscv64-linux-gnu)\n"
"exec ${CMAKE_C_COMPILER} \"\${extra_args[@]}\" \"$@\"\n"
)
	file(CHMOD "${_GST_CC_WRAPPER}"
		PERMISSIONS
			OWNER_READ OWNER_WRITE OWNER_EXECUTE
			GROUP_READ GROUP_EXECUTE
			WORLD_READ WORLD_EXECUTE
	)

	set(_GST_CXX_WRAPPER "${CMAKE_BINARY_DIR}/gstreamer-cxx-wrapper.sh")
	file(WRITE "${_GST_CXX_WRAPPER}"
"#!/usr/bin/env bash\n"
"set -e\n"
"extra_args=(${_GST_RISCV_ABI_FLAGS_STR})\n"
"extra_args+=(--sysroot=${CMAKE_SYSROOT})\n"
"extra_args+=(-L${CMAKE_SYSROOT}/usr/lib)\n"
"extra_args+=(-lGLX)\n"
"extra_args+=(-B${CMAKE_SYSROOT}/usr/lib/riscv64-linux-gnu)\n"
"extra_args+=(-B${CMAKE_SYSROOT}/lib/riscv64-linux-gnu)\n"
	"extra_args+=(-I${CMAKE_SYSROOT}/usr/include/riscv64-linux-gnu)\n"
"extra_args+=(-L${CMAKE_SYSROOT}/usr/lib/riscv64-linux-gnu)\n"
"extra_args+=(-L${CMAKE_SYSROOT}/lib/riscv64-linux-gnu)\n"
"extra_args+=(-Wl,-rpath-link,${CMAKE_SYSROOT}/usr/lib)\n"
"extra_args+=(-Wl,-rpath-link,${CMAKE_SYSROOT}/usr/lib/riscv64-linux-gnu)\n"
"extra_args+=(-Wl,-rpath-link,${CMAKE_SYSROOT}/lib/riscv64-linux-gnu)\n"
"exec ${CMAKE_CXX_COMPILER} \"\${extra_args[@]}\" \"$@\"\n"
)
	file(CHMOD "${_GST_CXX_WRAPPER}"
		PERMISSIONS
			OWNER_READ OWNER_WRITE OWNER_EXECUTE
			GROUP_READ GROUP_EXECUTE
			WORLD_READ WORLD_EXECUTE
	)

	file(WRITE "${_GST_MESON_CROSS_FILE}"
"[binaries]\n"
"c = '${_GST_CC_WRAPPER}'\n"
"cpp = '${_GST_CXX_WRAPPER}'\n"
"exe_wrapper = '${_GST_EXE_WRAPPER}'\n"
"${_GST_AR_ENTRY}"
"${_GST_RANLIB_ENTRY}"
"pkgconfig = '${_GST_PKG_CONFIG_WRAPPER}'\n"
"\n"
"[host_machine]\n"
"system = 'linux'\n"
"cpu_family = 'riscv64'\n"
"cpu = 'riscv64'\n"
"endian = 'little'\n"
"\n"
"[properties]\n"
"sys_root = '${CMAKE_SYSROOT}'\n"
"needs_exe_wrapper = true\n"
"\n"
"[built-in options]\n"
"c_args = [${_GST_MESON_COMPILE_ARGS}]\n"
"cpp_args = [${_GST_MESON_COMPILE_ARGS}]\n"
"c_link_args = [${_GST_MESON_LINK_ARGS}]\n"
"cpp_link_args = [${_GST_MESON_LINK_ARGS}]\n"
)

	list(APPEND _GST_MESON_SETUP_ARGS
		--cross-file "${_GST_MESON_CROSS_FILE}"
	)

	set(_GST_CONFIGURE_COMMAND
		${CMAKE_COMMAND} -E env
		PKG_CONFIG=${_GST_PKG_CONFIG_WRAPPER}
		PKG_CONFIG_SYSROOT_DIR=${CMAKE_SYSROOT}
		PKG_CONFIG_LIBDIR=${_GST_PKG_CONFIG_LIBDIR}
		PKG_CONFIG_PATH=
		QEMU_LD_PREFIX=${CMAKE_SYSROOT}
		PATH=${CMAKE_BINARY_DIR}:$ENV{PATH}
		${_GST_MESON_CMD} setup ${_GST_MESON_SETUP_ARGS} <SOURCE_DIR>
	)

	set(_GST_PREBUILD_SCRIPT "${CMAKE_BINARY_DIR}/gstreamer-prebuild.sh")
	set(_GST_SOURCE_DIR "${CMAKE_BINARY_DIR}/gstreamer/src/gstreamer")
	file(WRITE "${_GST_PREBUILD_SCRIPT}"
"#!/usr/bin/env bash\n"
"set -e\n"
"build_dir=\"$PWD\"\n"
"src_dir='${_GST_SOURCE_DIR}'\n"
"if [[ -d \"$build_dir/subprojects/freetype-2.13.3\" ]]; then\n"
"  if [[ -f \"$src_dir/subprojects/freetype-2.13.3/include/freetype/config/ftmodule.h\" ]]; then\n"
"    ln -sf \"$src_dir/subprojects/freetype-2.13.3/include/freetype/config/ftmodule.h\" \"$build_dir/subprojects/freetype-2.13.3/ftmodule.h\"\n"
"  fi\n"
"  if [[ -f \"$src_dir/subprojects/freetype-2.13.3/include/freetype/config/ftoption.h\" ]]; then\n"
"    ln -sf \"$src_dir/subprojects/freetype-2.13.3/include/freetype/config/ftoption.h\" \"$build_dir/subprojects/freetype-2.13.3/ftoption.h\"\n"
"  fi\n"
"fi\n"
"exec ninja\n"
)
	file(CHMOD "${_GST_PREBUILD_SCRIPT}"
		PERMISSIONS
			OWNER_READ OWNER_WRITE OWNER_EXECUTE
			GROUP_READ GROUP_EXECUTE
			WORLD_READ WORLD_EXECUTE
	)

	set(_GST_BUILD_COMMAND
		${CMAKE_COMMAND} -E env
		PKG_CONFIG=${_GST_PKG_CONFIG_WRAPPER}
		PKG_CONFIG_SYSROOT_DIR=${CMAKE_SYSROOT}
		PKG_CONFIG_LIBDIR=${_GST_PKG_CONFIG_LIBDIR}
		PKG_CONFIG_PATH=
		QEMU_LD_PREFIX=${CMAKE_SYSROOT}
		PATH=${CMAKE_BINARY_DIR}:$ENV{PATH}
		${_GST_PREBUILD_SCRIPT}
	)
	set(_GST_INSTALL_COMMAND
		${CMAKE_COMMAND} -E env
		PKG_CONFIG=${_GST_PKG_CONFIG_WRAPPER}
		PKG_CONFIG_SYSROOT_DIR=${CMAKE_SYSROOT}
		PKG_CONFIG_LIBDIR=${_GST_PKG_CONFIG_LIBDIR}
		PKG_CONFIG_PATH=
		QEMU_LD_PREFIX=${CMAKE_SYSROOT}
		PATH=${CMAKE_BINARY_DIR}:$ENV{PATH}
		${_GST_MESON_CMD} install
	)

	message(STATUS "GStreamer will be cross-compiled for ${_GST_HOST_TRIPLET} using Meson cross file: ${_GST_MESON_CROSS_FILE}")
endif()

# Note: the dependency scripts follow a template, this is left here should other
# dependencies be added in the future and this file used as a reference.
#
# find_package(PkgConfig)
# pkg_check_modules(GSTREAMER gstreamer-1.0=${DESIRED_VERSION})

# if (GSTREAMER_FOUND)
#     return()
# endif()

ExternalProject_Add(
	gstreamer
	PREFIX ${CMAKE_BINARY_DIR}/gstreamer
	GIT_REPOSITORY  https://gitlab.freedesktop.org/gstreamer/gstreamer.git
	GIT_TAG         ${DESIRED_VERSION}
	GIT_CONFIG      ${_GST_GIT_CONFIG}
	# Use external script for patch to avoid quoting issues; script handles idempotency and logging
	PATCH_COMMAND bash -c "bash ${CMAKE_CURRENT_SOURCE_DIR}/patches/apply_gst_patch.sh $(find ${CMAKE_CURRENT_SOURCE_DIR}/patches -maxdepth 1 -name '*.patch' -type f | sort)"
	BUILD_COMMAND       ${_GST_BUILD_COMMAND}
	INSTALL_COMMAND     ${_GST_INSTALL_COMMAND}
    TEST_COMMAND        ""
	CONFIGURE_COMMAND   ${_GST_CONFIGURE_COMMAND}
)

if (INSTALL_DLSTREAMER)
    execute_process(COMMAND mkdir -p ${DLSTREAMER_INSTALL_PREFIX}/gstreamer
                    COMMAND cp -r ${CMAKE_BINARY_DIR}/gstreamer-bin/. ${DLSTREAMER_INSTALL_PREFIX}/gstreamer)
endif()
