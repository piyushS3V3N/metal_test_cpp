#import "metal_context.hpp"
#import "objects.hpp"

MetalContext create_metal_context() {
    MetalContext ctx{};
    ctx.device = MTLCreateSystemDefaultDevice();
    ctx.queue = [ctx.device newCommandQueue];

    NSError *error = nil;
    NSString* executablePath = [[NSBundle mainBundle] executablePath];
    NSString* libraryPath = [[executablePath stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"shaders.metallib"];
    id<MTLLibrary> lib = [ctx.device newLibraryWithFile:libraryPath error:&error];
    if (!lib) {
        NSLog(@"Failed to load library at path %@. Error: %@", libraryPath, error);
        abort();
    }
    id<MTLFunction> vertexFn = [lib newFunctionWithName:@"vertex_main"];
    id<MTLFunction> fragmentFn = [lib newFunctionWithName:@"fragment_main"];

    MTLRenderPipelineDescriptor* pipelineDesc = [MTLRenderPipelineDescriptor new];
    pipelineDesc.vertexFunction = vertexFn;
    pipelineDesc.fragmentFunction = fragmentFn;
    pipelineDesc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    pipelineDesc.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float;

    MTLVertexDescriptor* vertexDesc = [MTLVertexDescriptor new];
    
    // Position
    vertexDesc.attributes[0].format = MTLVertexFormatFloat3;
    vertexDesc.attributes[0].offset = offsetof(Vertex, position);
    vertexDesc.attributes[0].bufferIndex = 0;

    // Normal
    vertexDesc.attributes[1].format = MTLVertexFormatFloat3;
    vertexDesc.attributes[1].offset = offsetof(Vertex, normal);
    vertexDesc.attributes[1].bufferIndex = 0;

    vertexDesc.layouts[0].stride = sizeof(Vertex);
    
    pipelineDesc.vertexDescriptor = vertexDesc;

    NSError* err = nil;
    ctx.pipeline = [ctx.device newRenderPipelineStateWithDescriptor:pipelineDesc error:&err];
    
    if (err) {
        NSLog(@"Error creating pipeline state: %@", err);
    }

    id<MTLFunction> landscapeVertexFn = [lib newFunctionWithName:@"landscape_vertex_main"];
    id<MTLFunction> landscapeFragmentFn = [lib newFunctionWithName:@"landscape_fragment_main"];
    pipelineDesc.vertexFunction = landscapeVertexFn;
    pipelineDesc.fragmentFunction = landscapeFragmentFn;
    
    NSError* landscapeErr = nil;
    ctx.landscape_pipeline = [ctx.device newRenderPipelineStateWithDescriptor:pipelineDesc error:&landscapeErr];

    if (landscapeErr) {
        NSLog(@"Error creating landscape pipeline state: %@", landscapeErr);
    }

    return ctx;
}