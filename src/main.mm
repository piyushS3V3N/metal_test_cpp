#define GLFW_EXPOSE_NATIVE_COCOA
#import <GLFW/glfw3.h>
#import <GLFW/glfw3native.h>

#import <Cocoa/Cocoa.h>
#import <QuartzCore/CAMetalLayer.h>

#include <chrono>
#include <vector>
#include <random>

#import "metal_context.hpp"
#import "camera.hpp"
#import "objects.hpp"
#import "landscape.hpp"
#import "cube.hpp"
#import "physics.hpp"

struct Uniforms {
    simd::float4x4 modelMatrix;
    simd::float4x4 viewMatrix;
    simd::float4x4 projectionMatrix;
    simd::float3 color;
    simd::float3 camera_pos;
    float time;
};

struct InputState {
    bool keys[1024] = {};
    double mouseX = 0.0, mouseY = 0.0;
};

InputState g_inputState;
bool g_cursor_locked = true;

void key_callback(GLFWwindow* window, int key, int scancode, int action, int mods) {
    if (action == GLFW_PRESS) {
        if (key == GLFW_KEY_ESCAPE) glfwSetWindowShouldClose(window, true);
        if (key == GLFW_KEY_TAB) {
            g_cursor_locked = !g_cursor_locked;
            glfwSetInputMode(window, GLFW_CURSOR, g_cursor_locked ? GLFW_CURSOR_DISABLED : GLFW_CURSOR_NORMAL);
        }
    }
    if (key >= 0 && key < 1024) {
        if (action == GLFW_PRESS) g_inputState.keys[key] = true;
        if (action == GLFW_RELEASE) g_inputState.keys[key] = false;
    }
}

void cursor_callback(GLFWwindow* window, double xpos, double ypos) {
    g_inputState.mouseX = xpos; g_inputState.mouseY = ypos;
}

// Improved Procedural Tree
void add_realistic_tree(std::vector<GameObject>& objects, simd::float3 pos) {
    // 1. Tapered Trunk
    GameObject trunk = create_cube();
    trunk.modelMatrix = matrix_translation(pos.x, pos.y + 1.2f, pos.z) * matrix_scale(0.12f, 2.4f, 0.12f);
    trunk.color = {0.25f, 0.18f, 0.1f};
    objects.push_back(trunk);

    // 2. Multi-layered canopy
    for(int i=0; i<3; ++i) {
        GameObject leaves = create_cube();
        float scale = 1.8f - (i * 0.4f);
        leaves.modelMatrix = matrix_translation(pos.x, pos.y + 2.0f + (i * 0.8f), pos.z) * matrix_scale(scale, 0.8f, scale);
        leaves.color = {0.1f, 0.35f + (i * 0.05f), 0.05f};
        objects.push_back(leaves);
    }
}

void add_item(std::vector<GameObject>& objects, simd::float3 pos, simd::float3 color) {
    GameObject item = create_cube();
    item.modelMatrix = matrix_translation(pos.x, pos.y + 0.3f, pos.z) * matrix_scale(0.2f, 0.4f, 0.2f);
    item.color = color;
    objects.push_back(item);
}

int main() {
    glfwInit();
    glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);
    GLFWwindow* window = glfwCreateWindow(1280, 720, "Metal Realistic World", nullptr, nullptr);
    MetalContext metal = create_metal_context();
    glfwSetKeyCallback(window, key_callback);
    glfwSetCursorPosCallback(window, cursor_callback);
    glfwSetInputMode(window, GLFW_CURSOR, GLFW_CURSOR_DISABLED);

    NSWindow* nsWindow = glfwGetCocoaWindow(window);
    CAMetalLayer* layer = [CAMetalLayer layer];
    layer.device = metal.device;
    layer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    nsWindow.contentView.layer = layer;
    nsWindow.contentView.wantsLayer = YES;

    std::vector<GameObject> world;
    // 1. Landscape
    world.push_back(create_landscape(128, 128));
    
    // 2. Character Legs (Visual only)
    GameObject legL = create_cube(); world.push_back(legL);
    GameObject legR = create_cube(); world.push_back(legR);
    int legStartIndex = world.size() - 2;

    // 3. Populate World
    std::mt19937 rng(42);
    std::uniform_real_distribution<float> d(-60, 60);
    for(int i=0; i<50; ++i) {
        float x = d(rng), z = d(rng);
        float y = get_terrain_height(x, z);
        if (y > 1.0f && y < 12.0f) add_realistic_tree(world, simd::float3{x, y, z});
        if (y > 12.0f) add_item(world, simd::float3{x, y, z}, simd::float3{0.9f, 0.1f, 0.9f}); // Crystals on peaks
    }

    // 4. Water Plane
    GameObject water = create_cube();
    water.modelMatrix = matrix_translation(0, -5.0f, 0) * matrix_scale(120, 0.1f, 120);
    water.color = {0.1f, 0.3f, 0.6f};
    world.push_back(water);

    std::vector<id<MTLBuffer>> vBufs, iBufs;
    for (const auto& go : world) {
        vBufs.push_back([metal.device newBufferWithBytes:go.vertices.data() length:go.vertices.size()*sizeof(Vertex) options:MTLResourceStorageModeShared]);
        iBufs.push_back([metal.device newBufferWithBytes:go.indices.data() length:go.indices.size()*sizeof(uint32_t) options:MTLResourceStorageModeShared]);
    }

    id<MTLBuffer> physicsBuffer = [metal.device newBufferWithLength:sizeof(PhysicsObject) options:MTLResourceStorageModeShared];
    ((PhysicsObject*)physicsBuffer.contents)->position = {0, 25, 0};
    ((PhysicsObject*)physicsBuffer.contents)->half_extents = {0.4, 0.9, 0.4};

    id<MTLBuffer> physUBuffer = [metal.device newBufferWithLength:sizeof(PhysicsUniforms) options:MTLResourceStorageModeShared];
    const int UNIFORM_STRIDE = (sizeof(Uniforms) + 255) & ~255;
    id<MTLBuffer> dynamicUBuffer = [metal.device newBufferWithLength:UNIFORM_STRIDE * 1024 options:MTLResourceStorageModeShared];

    id<MTLDepthStencilState> dsState = [metal.device newDepthStencilStateWithDescriptor:[MTLDepthStencilDescriptor new]];
    MTLDepthStencilDescriptor* dd = [MTLDepthStencilDescriptor new];
    dd.depthCompareFunction = MTLCompareFunctionLess; dd.depthWriteEnabled = YES;
    dsState = [metal.device newDepthStencilStateWithDescriptor:dd];
    id<MTLTexture> dTex = [metal.device newTextureWithDescriptor:[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatDepth32Float width:1280 height:720 mipmapped:NO]];

    Camera cam = make_camera(1280, 720);
    cam.projectionMatrix = matrix_perspective_right_hand(M_PI/3.2, 1280.0/720.0, 0.1, 800.0);
    auto start = std::chrono::high_resolution_clock::now();
    auto last = start;

    while (!glfwWindowShouldClose(window)) {
        auto now = std::chrono::high_resolution_clock::now();
        float dt = std::min(std::chrono::duration<float>(now - last).count(), 0.033f);
        float time = std::chrono::duration<float>(now - start).count();
        last = now;
        glfwPollEvents();

        simd::float2 mi = {0, 0}; int ji = 0;
        if (g_cursor_locked) {
            double mx = g_inputState.mouseX, my = g_inputState.mouseY;
            static double lmx = mx, lmy = my;
            cam.yaw += (mx - lmx) * 0.12f; cam.pitch -= (my - lmy) * 0.12f;
            cam.pitch = std::clamp(cam.pitch, -85.0f, 85.0f);
            lmx = mx; lmy = my;
            float yr = cam.yaw * M_PI/180.0;
            simd_float3 f = {sinf(yr), 0, -cosf(yr)}, r = {cosf(yr), 0, sinf(yr)};
            if (g_inputState.keys[GLFW_KEY_W]) mi.y += 1; if (g_inputState.keys[GLFW_KEY_S]) mi.y -= 1;
            if (g_inputState.keys[GLFW_KEY_D]) mi.x += 1; if (g_inputState.keys[GLFW_KEY_A]) mi.x -= 1;
            if (g_inputState.keys[GLFW_KEY_SPACE]) ji = 1;
            if (simd_length(mi) > 0.1) {
                simd_float3 wm = f * mi.y + r * mi.x; mi = {wm.x, wm.z};
            }
        }
        PhysicsObject* pObj = (PhysicsObject*)physicsBuffer.contents;
        cam.position = pObj->position + simd_float3{0, 0.75, 0};
        update_camera_matrices(cam);

        // Update Leg Matrices relative to player
        float yr = cam.yaw * M_PI/180.0;
        simd_float3 forward = {sinf(yr), 0, -cosf(yr)};
        simd_float3 right = {cosf(yr), 0, sinf(yr)};
        float legSwing = sin(time * 10.0) * 0.2f * (simd_length(mi) > 0.1 ? 1.0 : 0.0);
        
        world[legStartIndex].modelMatrix = matrix_translation(pObj->position.x + right.x*0.2 + forward.x*legSwing, pObj->position.y - 0.6f, pObj->position.z + right.z*0.2 + forward.z*legSwing) * matrix_scale(0.15, 0.6, 0.15);
        world[legStartIndex+1].modelMatrix = matrix_translation(pObj->position.x - right.x*0.2 - forward.x*legSwing, pObj->position.y - 0.6f, pObj->position.z - right.z*0.2 - forward.z*legSwing) * matrix_scale(0.15, 0.6, 0.15);
        world[legStartIndex].color = {0.2, 0.4, 0.8}; // Blue pants
        world[legStartIndex+1].color = {0.2, 0.4, 0.8};

        id<CAMetalDrawable> drawable = [layer nextDrawable];
        if (drawable) {
            id<MTLCommandBuffer> cmd = [metal.queue commandBuffer];
            
            PhysicsUniforms pu; pu.gravity = {0, -25.0, 0}; pu.dt = dt; pu.terrain_size = 128;
            pu.player_move_intent = mi; pu.player_jump = ji;
            memcpy(physUBuffer.contents, &pu, sizeof(pu));

            id<MTLComputeCommandEncoder> ce = [cmd computeCommandEncoder];
            [ce setComputePipelineState:metal.physics_pipeline];
            [ce setBuffer:physicsBuffer offset:0 atIndex:0];
            [ce setBuffer:physUBuffer offset:0 atIndex:1];
            [ce dispatchThreads:MTLSizeMake(1,1,1) threadsPerThreadgroup:MTLSizeMake(1,1,1)];
            [ce endEncoding];

            MTLRenderPassDescriptor* pd = [MTLRenderPassDescriptor renderPassDescriptor];
            pd.colorAttachments[0].texture = drawable.texture;
            pd.colorAttachments[0].loadAction = MTLLoadActionClear;
            pd.colorAttachments[0].clearColor = MTLClearColorMake(0.4, 0.6, 0.9, 1.0);
            pd.depthAttachment.texture = dTex; pd.depthAttachment.loadAction = MTLLoadActionClear; pd.depthAttachment.clearDepth = 1.0;

            id<MTLRenderCommandEncoder> re = [cmd renderCommandEncoderWithDescriptor:pd];
            [re setDepthStencilState:dsState];

            for (size_t i = 0; i < world.size(); ++i) {
                [re setRenderPipelineState:(i == 0 ? metal.landscape_pipeline : metal.pipeline)];
                [re setVertexBuffer:vBufs[i] offset:0 atIndex:0];
                Uniforms u; u.modelMatrix = world[i].modelMatrix;
                u.viewMatrix = cam.viewMatrix; u.projectionMatrix = cam.projectionMatrix;
                u.color = world[i].color; u.camera_pos = cam.position; u.time = time;
                void* dest = (uint8_t*)dynamicUBuffer.contents + (i * UNIFORM_STRIDE);
                memcpy(dest, &u, sizeof(u));
                [re setVertexBuffer:dynamicUBuffer offset:(i * UNIFORM_STRIDE) atIndex:1];
                [re setFragmentBuffer:dynamicUBuffer offset:(i * UNIFORM_STRIDE) atIndex:1];
                [re drawIndexedPrimitives:MTLPrimitiveTypeTriangle indexCount:world[i].indices.size() indexType:MTLIndexTypeUInt32 indexBuffer:iBufs[i] indexBufferOffset:0];
            }
            [re endEncoding];
            [cmd presentDrawable:drawable];
            [cmd commit];
        }
    }
    glfwTerminate();
    return 0;
}
