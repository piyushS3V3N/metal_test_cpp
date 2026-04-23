#pragma once
#include <simd/simd.h>

struct PhysicsObject {
    simd::float3 position;
    float mass;
    
    simd::float3 velocity;
    float restitution;
    
    // Quaternion for rotation (x, y, z, w)
    simd::float4 rotation;
    
    simd::float3 angular_velocity;
    float padding1;
    
    simd::float3 half_extents;
    float padding2;
    
    simd::float3 color;
    float padding3;
};

// We also need a struct to pass global simulation parameters to the compute shader
struct PhysicsUniforms {
    simd::float3 gravity;
    float dt;
    float terrain_size;
    
    // Player Input
    simd::float2 player_move_intent; // x: right, y: forward
    int player_jump;
    float padding[2];
};
