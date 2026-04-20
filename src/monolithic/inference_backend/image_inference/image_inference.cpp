/*******************************************************************************
 * Copyright (C) 2018-2025 Intel Corporation
 *
 * SPDX-License-Identifier: MIT
 ******************************************************************************/

#include "image_inference_async/image_inference_async.h"
#ifdef ENABLE_OPENVINO_BACKEND
#include "openvino_image_inference.h"
#endif
#ifdef ENABLE_LIBTORCH
#include "libtorch_image_inference.h"
#endif
#ifdef ENABLE_TFLITE
#include "tflite/tflite_image_inference.h"
#endif
#include "utils.h"
#ifdef _MSC_VER
#include "image_inference_async_d3d11/image_inference_async_d3d11.h"
#endif

using namespace InferenceBackend;

namespace {

#if defined(ENABLE_OPENVINO_BACKEND) || defined(ENABLE_TFLITE) || defined(ENABLE_LIBTORCH)
enum class InferenceBackendType {
    OPENVINO,
    TFLITE,
    LIBTORCH
};

InferenceBackendType getInferenceBackendType(const std::map<std::string, std::string> &base_config) {
    constexpr const char *kInferenceBackendKey = "inference-backend";
    auto it = base_config.find(kInferenceBackendKey);
    if (it == base_config.end()) {
#ifdef ENABLE_OPENVINO_BACKEND
        return InferenceBackendType::OPENVINO;
#elif defined(ENABLE_TFLITE)
        return InferenceBackendType::TFLITE;
#elif defined(ENABLE_LIBTORCH)
        return InferenceBackendType::LIBTORCH;
#else
        throw std::runtime_error("No inference backend built. Enable at least one backend.");
#endif
    }
#ifdef ENABLE_LIBTORCH
    if (it->second == "LIBTORCH")
        return InferenceBackendType::LIBTORCH;
#endif
#ifdef ENABLE_TFLITE
    if (it->second == "TFLITE")
        return InferenceBackendType::TFLITE;
#endif
    if (it->second == "OPENVINO")
#ifdef ENABLE_OPENVINO_BACKEND
        return InferenceBackendType::OPENVINO;
#else
        throw std::runtime_error("OpenVINO backend requested but not built (ENABLE_OPENVINO_BACKEND=OFF)");
#endif

    if (it->second == "LIBTORCH") {
        throw std::runtime_error("LibTorch backend requested but not built (ENABLE_LIBTORCH=OFF)");
    }

    throw std::runtime_error("Unknown inference backend type");
}

ImagePreprocessorType getPreProcType(const std::map<std::string, std::string> &base_config) {
    auto it = base_config.find(KEY_PRE_PROCESSOR_TYPE);
    if (it == base_config.end())
        throw std::runtime_error("Image pre-processor type is not set");
    return static_cast<ImagePreprocessorType>(std::stoi(it->second));
}
#endif

} // namespace

std::map<std::string, GstStructure *> ImageInference::GetModelInfoPreproc(const std::string model_file,
                                                                          const gchar *preproc_config,
                                                                          const gchar *ov_extension_lib) {
#ifdef ENABLE_OPENVINO_BACKEND
    return OpenVINOImageInference::GetModelInfoPreproc(model_file, preproc_config, ov_extension_lib);
#else
    UNUSED(model_file);
    UNUSED(preproc_config);
    UNUSED(ov_extension_lib);
    return {};
#endif
}

ImageInference::Ptr ImageInference::createImageInferenceInstance(MemoryType input_image_memory_type,
                                                                 const InferenceConfig &config, Allocator *allocator,
                                                                 CallbackFunc callback, ErrorHandlingFunc error_handler,
                                                                 dlstreamer::ContextPtr context) {
#if !defined(ENABLE_OPENVINO_BACKEND) && !defined(ENABLE_TFLITE) && !defined(ENABLE_LIBTORCH)
    UNUSED(input_image_memory_type);
    UNUSED(config);
    UNUSED(allocator);
    UNUSED(callback);
    UNUSED(error_handler);
    UNUSED(context);
    throw std::runtime_error("No matching inference backend available for requested configuration");
#else
    bool async_mode = false;
    MemoryType memory_type_to_use = MemoryType::ANY;

    switch (input_image_memory_type) {
    case MemoryType::SYSTEM:
        memory_type_to_use = input_image_memory_type;
        break;

    case MemoryType::DMA_BUFFER:
    case MemoryType::VAAPI: {
        async_mode = true;
        if (!context) {
            throw std::invalid_argument("Null context provided (VaApiContext is expected)");
        }

        ImagePreprocessorType preproc_type = getPreProcType(config.at(KEY_BASE));
        switch (preproc_type) {
        case ImagePreprocessorType::VAAPI_SYSTEM:
            memory_type_to_use = MemoryType::SYSTEM;
            break;
        case ImagePreprocessorType::VAAPI_SURFACE_SHARING:
            memory_type_to_use = MemoryType::VAAPI;
            break;

        default:
            throw std::runtime_error("Incorrect pre-process-backend, should be vaapi or vaapi-surface-sharing");
        }
        break;
    }

    case MemoryType::D3D11: {
        async_mode = true;
        if (!context) {
            throw std::invalid_argument("Null context provided (D3D11Context is expected)");
        }
        ImagePreprocessorType preproc_type = getPreProcType(config.at(KEY_BASE));
        switch (preproc_type) {
        case ImagePreprocessorType::D3D11:
            memory_type_to_use = MemoryType::SYSTEM;
            break;
        case ImagePreprocessorType::D3D11_SURFACE_SHARING:
            memory_type_to_use = MemoryType::D3D11;
            throw std::runtime_error("Not implemented yet");
            break;
        default:
            throw std::runtime_error("Incorrect pre-process-backend, should be d3d11 or d3d11-surface-sharing");
        }
        break;
    }
    default:
        throw std::invalid_argument("Unsupported memory type");
    }

    ImageInference::Ptr inference_instance;
    auto backend_type = getInferenceBackendType(config.at(KEY_BASE));
    (void)backend_type;
#ifdef ENABLE_LIBTORCH
    if (backend_type == InferenceBackendType::LIBTORCH) {
        inference_instance = std::make_shared<LibTorchImageInference>(config, allocator, context, callback,
                                                                      error_handler, memory_type_to_use);
    } else
#endif
#ifdef ENABLE_TFLITE
    if (backend_type == InferenceBackendType::TFLITE) {
        inference_instance = std::make_shared<TFLiteImageInference>(config, allocator, context, callback,
                                                                    error_handler, memory_type_to_use);
    } else
#endif
#ifdef ENABLE_OPENVINO_BACKEND
    {
        inference_instance = std::make_shared<OpenVINOImageInference>(config, allocator, context, callback,
                                                                      error_handler, memory_type_to_use);
    }
#else
    {
        throw std::runtime_error("No matching inference backend available for requested configuration");
    }
#endif

    ImageInference::Ptr result_inference;
    if (async_mode) {
#ifdef ENABLE_VAAPI
#ifndef _MSC_VER
        result_inference = std::make_shared<ImageInferenceAsync>(config, context, std::move(inference_instance));
#endif
#endif
#ifdef _MSC_VER
        result_inference = std::make_shared<ImageInferenceAsyncD3D11>(config, context, std::move(inference_instance));
#endif
    } else {
        result_inference = std::move(inference_instance);
    }

    return result_inference;
#endif
}