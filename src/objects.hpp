#pragma once

#include <simd/simd.h>
#include <vector>


struct Vertex {
    simd::float3 position;
    simd::float3 normal;
};

struct GameObject {
    simd::float4x4 modelMatrix;
    simd::float3 color;
    std::vector<Vertex> vertices;
    std::vector<uint32_t> indices;
};

