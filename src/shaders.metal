#include <metal_stdlib>
using namespace metal;

struct Vertex {
    float3 position [[attribute(0)]];
    float3 normal   [[attribute(1)]];
};

struct Uniforms {
    float4x4 modelMatrix;
    float4x4 viewMatrix;
    float4x4 projectionMatrix;
    float3 color;
    float3 camera_pos;
    float time;
};

struct PhysicsObject {
    float3 position;
    float mass;
    float3 velocity;
    float restitution;
    float4 rotation;
    float3 angular_velocity;
    float padding1;
    float3 half_extents;
    float padding2;
    float3 color;
    float padding3;
};

struct PhysicsUniforms {
    float3 gravity;
    float dt;
    float terrain_size;
    float2 player_move_intent;
    int player_jump;
    float padding[2];
};

// --- Noise Logic ---
float hash(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float a = hash(i);
    float b = hash(i + float2(1.0, 0.0));
    float c = hash(i + float2(0.0, 1.0));
    float d = hash(i + float2(1.0, 1.0));
    float2 u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float get_fractal_noise(float2 p) {
    float total = 0, freq = 1.0, amp = 1.0;
    for(int i = 0; i < 7; i++) {
        total += noise(p * freq) * amp;
        amp *= 0.5; freq *= 2.0;
    }
    return total;
}

float get_terrain_height(float x, float z) {
    float2 p = (float2(x, z) + 128.0) / 256.0 * 3.5;
    return get_fractal_noise(p) * 22.0 - 5.0;
}

// --- Physics ---
kernel void physics_step(device PhysicsObject* objects [[buffer(0)]],
                         constant PhysicsUniforms& uniforms [[buffer(1)]],
                         uint id [[thread_position_in_grid]]) {
    PhysicsObject obj = objects[id];
    float3 move = float3(uniforms.player_move_intent.x, 0, uniforms.player_move_intent.y);
    float3 target_vel = move * 12.0;
    obj.velocity.xz += (target_vel.xz - obj.velocity.xz) * 15.0 * uniforms.dt;
    float gy = get_terrain_height(obj.position.x, obj.position.z);
    bool grounded = (obj.position.y - obj.half_extents.y <= gy + 0.1);
    if (!grounded) obj.velocity.y += uniforms.gravity.y * uniforms.dt;
    else if (uniforms.player_jump > 0) obj.velocity.y = 9.0;
    obj.position += obj.velocity * uniforms.dt;
    gy = get_terrain_height(obj.position.x, obj.position.z);
    if (obj.position.y - obj.half_extents.y < gy) {
        obj.position.y = gy + obj.half_extents.y;
        obj.velocity.y = 0;
    }
    float b = uniforms.terrain_size / 2.0 - 2.0;
    obj.position.xz = clamp(obj.position.xz, -b, b);
    objects[id] = obj;
}

// --- Rendering ---
struct VertexOut {
    float4 position [[position]];
    float3 world_pos;
    float3 normal;
    float3 view_dir;
    float3 color;
};

vertex VertexOut vertex_main(const Vertex in [[stage_in]], constant Uniforms &u [[buffer(1)]]) {
    VertexOut out;
    float3 pos = in.position;
    
    // Simple Wind for "Realistic Trees" (If object is green, assume it's leaves)
    if (u.color.g > u.color.r && u.color.g > u.color.b) {
        float wind = sin(u.time * 2.0 + in.position.x + in.position.z) * 0.1;
        pos.xz += wind * saturate(in.position.y);
    }

    float4 world_pos = u.modelMatrix * float4(pos, 1.0);
    out.position = u.projectionMatrix * u.viewMatrix * world_pos;
    out.world_pos = world_pos.xyz;
    out.normal = (u.modelMatrix * float4(in.normal, 0.0)).xyz;
    out.view_dir = normalize(u.camera_pos - world_pos.xyz);
    out.color = u.color;
    return out;
}

vertex VertexOut landscape_vertex_main(const Vertex in [[stage_in]], constant Uniforms &u [[buffer(1)]]) {
    VertexOut out;
    float4 world_pos = u.modelMatrix * float4(in.position, 1.0);
    out.position = u.projectionMatrix * u.viewMatrix * world_pos;
    out.world_pos = world_pos.xyz;
    out.normal = (u.modelMatrix * float4(in.normal, 0.0)).xyz;
    out.view_dir = normalize(u.camera_pos - world_pos.xyz);
    out.color = u.color;
    return out;
}

fragment float4 fragment_main(VertexOut in [[stage_in]], constant Uniforms &u [[buffer(1)]]) {
    float3 N = normalize(in.normal);
    float3 L = normalize(float3(0.5, 0.8, 0.2));
    float3 V = normalize(in.view_dir);
    float3 H = normalize(L + V);
    
    float diff = saturate(dot(N, L)) * 0.8 + 0.2;
    float spec = pow(saturate(dot(N, H)), 32.0) * 0.3;
    
    // Emission for items (Purple/Cyan items glow)
    float glow = 0.0;
    if (in.color.r > 0.8 && in.color.b > 0.8) glow = 2.0; // Purple crystals glow
    
    float3 final = (in.color * diff + spec) + (in.color * glow);
    
    float dist = length(u.camera_pos - in.world_pos);
    float fog = saturate(exp(-dist * 0.015));
    return float4(mix(float3(0.4, 0.6, 0.9), final, fog), 1.0);
}

fragment float4 landscape_fragment_main(VertexOut in [[stage_in]], constant Uniforms &u [[buffer(1)]]) {
    float3 dX = dfdx(in.world_pos);
    float3 dY = dfdy(in.world_pos);
    float3 N = normalize(cross(dX, dY));
    
    float slope = 1.0 - saturate(dot(N, float3(0, 1, 0)));
    float3 grass = float3(0.12, 0.25, 0.08);
    float3 dirt = float3(0.25, 0.2, 0.15);
    float3 rock = float3(0.3, 0.3, 0.3);
    float3 snow = float3(0.95, 0.95, 1.0);
    
    float3 base;
    if (in.world_pos.y > 13.0) base = mix(rock, snow, saturate((in.world_pos.y - 13.0)/3.0));
    else if (slope > 0.55) base = rock;
    else if (in.world_pos.y < 0.5) base = float3(0.7, 0.6, 0.4); // Sand
    else base = mix(grass, dirt, saturate(slope * 3.0));
    
    float3 L = normalize(float3(0.5, 0.8, 0.2));
    float diff = saturate(dot(N, L)) * 0.8 + 0.2;
    float3 final = base * diff;
    
    float dist = length(u.camera_pos - in.world_pos);
    float fog = saturate(exp(-dist * 0.01));
    float3 sky = float3(0.4, 0.6, 0.9);
    
    // Simple Water Reflection hack
    if (in.world_pos.y < -4.5) final = mix(final, float3(0.1, 0.3, 0.6), 0.5);

    return float4(mix(sky, final, fog), 1.0);
}
