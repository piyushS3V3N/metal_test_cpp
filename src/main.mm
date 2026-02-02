#define GLFW_EXPOSE_NATIVE_COCOA
#import <GLFW/glfw3.h>
#import <GLFW/glfw3native.h>

#import <Cocoa/Cocoa.h>
#import <QuartzCore/CAMetalLayer.h>

#include <chrono>
#include <vector>

#import "metal_context.hpp"
#import "camera.hpp"
#import "objects.hpp"
#import "landscape.hpp"
#import "cube.hpp"

#import "imgui.h"
#import "imgui_impl_glfw.h"
#import "imgui_impl_metal.h"

// Shader uniform structure
struct Uniforms {
    simd::float4x4 modelMatrix;
    simd::float4x4 viewMatrix;
    simd::float4x4 projectionMatrix;
    simd::float3 color;
};

// Global state for input handling
struct InputState {
    bool keys[1024] = {};
    double mouseX = 0.0;
    double mouseY = 0.0;
};

InputState g_inputState;
bool g_cursor_locked = true;

// GLFW callbacks
void key_callback(GLFWwindow* window, int key, int scancode, int action, int mods) {
    if (action == GLFW_PRESS) {
        if (key == GLFW_KEY_ESCAPE) {
            glfwSetWindowShouldClose(window, true);
        }
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
    g_inputState.mouseX = xpos;
    g_inputState.mouseY = ypos;
}

void add_tree(std::vector<GameObject>& objects, simd::float3 position) {
    GameObject trunk = create_cube();
    trunk.modelMatrix = matrix_translation(position.x, position.y + 1.0f, position.z) * matrix_scale(0.2f, 2.0f, 0.2f);
    trunk.color = {0.5f, 0.35f, 0.26f};
    objects.push_back(trunk);

    GameObject leaves = create_cube();
    leaves.modelMatrix = matrix_translation(position.x, position.y + 2.5f, position.z) * matrix_scale(1.5f, 1.5f, 1.5f);
    leaves.color = {0.0f, 0.8f, 0.2f};
    objects.push_back(leaves);
}

int main() {
    const uint32_t WIDTH  = 800;
    const uint32_t HEIGHT = 600;

    glfwInit();
    glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);

    GLFWwindow* window =
        glfwCreateWindow(WIDTH, HEIGHT, "OpenWorld Simulation", nullptr, nullptr);

    MetalContext metal = create_metal_context();

    glfwSetKeyCallback(window, key_callback);
    glfwSetCursorPosCallback(window, cursor_callback);
    glfwSetInputMode(window, GLFW_CURSOR, GLFW_CURSOR_DISABLED);

    NSWindow* nsWindow = glfwGetCocoaWindow(window);
    nsWindow.contentView.wantsLayer = YES;

    CAMetalLayer* layer = [CAMetalLayer layer];
    layer.device = metal.device;
    layer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    layer.framebufferOnly = YES;
    layer.drawableSize = CGSizeMake(WIDTH, HEIGHT);
    nsWindow.contentView.layer = layer;

    // --- ImGui Setup ---
    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGuiIO& io = ImGui::GetIO(); (void)io;
    ImGui::StyleColorsDark();
    ImGui_ImplGlfw_InitForOpenGL(window, true);
    ImGui_ImplMetal_Init(metal.device);

    std::vector<GameObject> gameObjects;

    GameObject landscape = create_landscape(50, 50);
    gameObjects.push_back(landscape);

    add_tree(gameObjects, simd::float3{5.0f, get_terrain_height(5.0f, 5.0f), 5.0f});
    add_tree(gameObjects, simd::float3{-8.0f, get_terrain_height(-8.0f, -10.0f), -10.0f});
    add_tree(gameObjects, simd::float3{10.0f, get_terrain_height(10.0f, -5.0f), -5.0f});

    GameObject rock = create_cube();
    rock.modelMatrix = matrix_translation(-5.0f, get_terrain_height(-5.0f, -5.0f) + 0.5f, -5.0f) * matrix_scale(1.5f, 1.0f, 2.5f);
    rock.color = {0.5f, 0.5f, 0.5f};
    gameObjects.push_back(rock);

    // --- Create Metal Buffers for GameObjects ---
    std::vector<id<MTLBuffer>> vertexBuffers;
    std::vector<id<MTLBuffer>> indexBuffers;

    for (const auto& go : gameObjects) {
        id<MTLBuffer> vertexBuffer =
            [metal.device newBufferWithBytes:go.vertices.data()
                                      length:go.vertices.size() * sizeof(Vertex)
                                     options:MTLResourceStorageModeShared];
        vertexBuffers.push_back(vertexBuffer);

        id<MTLBuffer> indexBuffer =
            [metal.device newBufferWithBytes:go.indices.data()
                                      length:go.indices.size() * sizeof(uint32_t)
                                     options:MTLResourceStorageModeShared];
        indexBuffers.push_back(indexBuffer);
    }


    id<MTLBuffer> uniformBuffer =
        [metal.device newBufferWithLength:sizeof(Uniforms)
                                  options:MTLResourceStorageModeShared];
                                  
    MTLDepthStencilDescriptor* depthDesc = [MTLDepthStencilDescriptor new];
    depthDesc.depthCompareFunction = MTLCompareFunctionLess;
    depthDesc.depthWriteEnabled = YES;
    id<MTLDepthStencilState> depthState = [metal.device newDepthStencilStateWithDescriptor:depthDesc];

    MTLTextureDescriptor* depthTexDesc = 
        [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatDepth32Float
                                                           width:WIDTH
                                                          height:HEIGHT
                                                       mipmapped:NO];
    depthTexDesc.storageMode = MTLStorageModePrivate;
    depthTexDesc.usage = MTLTextureUsageRenderTarget;
    id<MTLTexture> depthTexture = [metal.device newTextureWithDescriptor:depthTexDesc];


    Camera cam = make_camera(WIDTH, HEIGHT);
    
    auto lastTime = std::chrono::high_resolution_clock::now();

    while (!glfwWindowShouldClose(window)) {
        auto currentTime = std::chrono::high_resolution_clock::now();
        float dt = std::chrono::duration<float>(currentTime - lastTime).count();
        lastTime = currentTime;

        glfwPollEvents();
        if (g_cursor_locked) {
            update_camera(cam, dt, g_inputState.keys, g_inputState.mouseX, g_inputState.mouseY);

            // Clamp camera to terrain
            float terrain_height = get_terrain_height(cam.position.x, cam.position.z);
            if (cam.position.y < terrain_height + 1.5f) { // 1.5f is camera height above ground
                cam.position.y = terrain_height + 1.5f;
            }
        }

        id<CAMetalDrawable> drawable = [layer nextDrawable];
        if (drawable) {
            MTLRenderPassDescriptor* passDesc = [MTLRenderPassDescriptor renderPassDescriptor];
            passDesc.colorAttachments[0].texture = drawable.texture;
            passDesc.colorAttachments[0].loadAction = MTLLoadActionClear;
            passDesc.colorAttachments[0].storeAction = MTLStoreActionStore;
            passDesc.colorAttachments[0].clearColor = MTLClearColorMake(0.6, 0.8, 1.0, 1.0); // Sky blue
            
            passDesc.depthAttachment.texture = depthTexture;
            passDesc.depthAttachment.loadAction = MTLLoadActionClear;
            passDesc.depthAttachment.storeAction = MTLStoreActionDontCare;
            passDesc.depthAttachment.clearDepth = 1.0;

            id<MTLCommandBuffer> cmd = [metal.queue commandBuffer];
            id<MTLRenderCommandEncoder> enc = [cmd renderCommandEncoderWithDescriptor:passDesc];

            [enc setRenderPipelineState:metal.pipeline];
            [enc setDepthStencilState:depthState];
            [enc setVertexBuffer:uniformBuffer offset:0 atIndex:1];

            for (size_t i = 0; i < gameObjects.size(); ++i) {
                const auto& go = gameObjects[i];

                if (i == 0) { // Index 0 is the landscape
                    [enc setRenderPipelineState:metal.landscape_pipeline];
                } else {
                    [enc setRenderPipelineState:metal.pipeline];
                }

                [enc setVertexBuffer:vertexBuffers[i] offset:0 atIndex:0];

                Uniforms uniforms;
                uniforms.modelMatrix = go.modelMatrix;
                uniforms.viewMatrix = cam.viewMatrix;
                uniforms.projectionMatrix = cam.projectionMatrix;
                uniforms.color = go.color;
                memcpy(uniformBuffer.contents, &uniforms, sizeof(Uniforms));
                
                [enc drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                                indexCount:go.indices.size()
                                 indexType:MTLIndexTypeUInt32
                               indexBuffer:indexBuffers[i]
                         indexBufferOffset:0];
            }

            // --- ImGui Rendering ---
            ImGui_ImplMetal_NewFrame(passDesc);
            ImGui_ImplGlfw_NewFrame();
            ImGui::NewFrame();

            ImGui::Begin("Controls");
            ImGui::Text("Move: W, A, S, D");
            ImGui::Text("Look: Mouse");
            ImGui::Text("Up/Down: Space/C");
            ImGui::Text("Toggle Cursor Lock: Tab");
            ImGui::Text("Exit: Esc");
            ImGui::End();

            ImGui::Render();
            ImGui_ImplMetal_RenderDrawData(ImGui::GetDrawData(), cmd, enc);


            [enc endEncoding];

            [cmd presentDrawable:drawable];
            [cmd commit];
        }
    }

    // --- ImGui Shutdown ---
    ImGui_ImplMetal_Shutdown();
    ImGui_ImplGlfw_Shutdown();
    ImGui::DestroyContext();

    glfwTerminate();
    return 0;
}