#include <metal_stdlib>
using namespace metal;

// Structs used by both pipelines
struct Vertex {
    float3 position [[attribute(0)]];
    float3 normal   [[attribute(1)]];
};

struct Uniforms {
    float4x4 modelMatrix;
    float4x4 viewMatrix;
    float4x4 projectionMatrix;
    float3 color;
};

// --- Default Object Shaders ---

struct VertexOut {
    float4 position [[position]];
    float3 normal_ws; // World space normal
};

vertex VertexOut vertex_main(const Vertex in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(1)]]) {
    VertexOut out;
    float4 pos = float4(in.position, 1.0);
    out.position = uniforms.projectionMatrix * uniforms.viewMatrix * uniforms.modelMatrix * pos;
    out.normal_ws = (uniforms.modelMatrix * float4(in.normal, 0.0)).xyz;
    return out;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant Uniforms &uniforms [[buffer(1)]]) {
    float3 light_dir = normalize(float3(0.8, 1.0, 0.5));
    float diffuse_k = saturate(dot(normalize(in.normal_ws), light_dir));
    float3 ambient = float3(0.2, 0.2, 0.2);
    float3 final_color = uniforms.color * ambient + uniforms.color * diffuse_k;
    return float4(final_color, 1.0);
}

// --- Landscape Shaders ---

struct LandscapeVertexOut {
    float4 position [[position]];
    float3 normal_ws; // World space normal
    float  height;
};

vertex LandscapeVertexOut landscape_vertex_main(const Vertex in [[stage_in]],
                                                 constant Uniforms &uniforms [[buffer(1)]]) {
    LandscapeVertexOut out;
    float4 world_pos = uniforms.modelMatrix * float4(in.position, 1.0);
    out.position = uniforms.projectionMatrix * uniforms.viewMatrix * world_pos;
    out.normal_ws = (uniforms.modelMatrix * float4(in.normal, 0.0)).xyz;
    out.height = world_pos.y;
    return out;
}

fragment float4 landscape_fragment_main(LandscapeVertexOut in [[stage_in]]) {
    float3 final_color;
    float3 grass_color = float3(0.3, 0.6, 0.2);
    float3 rock_color = float3(0.5, 0.5, 0.5);
    float3 snow_color = float3(1.0, 1.0, 1.0);

    if (in.height > 8.0) {
        final_color = snow_color;
    } else if (in.height > 4.0) {
        float blend = (in.height - 4.0) / 4.0;
        final_color = mix(rock_color, snow_color, blend);
    } else if (in.height > 0.0) {
        float blend = (in.height - 0.0) / 4.0;
        final_color = mix(grass_color, rock_color, blend);
    } else {
        final_color = grass_color;
    }

    float3 light_dir = normalize(float3(0.8, 1.0, 0.5));
    float diffuse_k = saturate(dot(normalize(in.normal_ws), light_dir));
    float3 ambient = float3(0.2, 0.2, 0.2);
    
    final_color = final_color * ambient + final_color * diffuse_k;
    
    return float4(final_color, 1.0);
}
