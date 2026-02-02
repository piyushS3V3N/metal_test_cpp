#pragma once
#import <Metal/Metal.h>

struct MetalContext {
    id<MTLDevice> device;               ///< The Metal device.
    id<MTLCommandQueue> queue;          ///< The Metal command queue.
    id<MTLRenderPipelineState> pipeline; ///< Default render pipeline for general objects.
    id<MTLRenderPipelineState> landscape_pipeline; ///< Render pipeline specifically for the landscape.
};


MetalContext create_metal_context();