
#include "landscape.hpp"
#include "camera.hpp"
#include <cstdlib>
#include <ctime>
#include <cmath>

// --- Noise functions ---
namespace {
    const int LANDSCAPE_WIDTH = 50;
    const int LANDSCAPE_DEPTH = 50;
    const float TERRAIN_SCALE = 5.0f;
    const float TERRAIN_HEIGHT = 12.0f;
}

float simple_noise(int x, int z) {
    int n = x + z * 57;
    n = (n << 13) ^ n;
    return (1.0f - ((n * (n * n * 15731 + 789221) + 1376312589) & 0x7fffffff) / 1073741824.0f);
}

float cosine_interpolate(float a, float b, float blend) {
    float ft = blend * 3.1415927f;
    float f = (1.0f - cosf(ft)) * 0.5f;
    return a * (1.0f - f) + b * f;
}

float smoothed_noise(float x, float z) {
    int int_x = static_cast<int>(floorf(x));
    int int_z = static_cast<int>(floorf(z));
    float frac_x = x - int_x;
    float frac_z = z - int_z;

    float v1 = simple_noise(int_x, int_z);
    float v2 = simple_noise(int_x + 1, int_z);
    float v3 = simple_noise(int_x, int_z + 1);
    float v4 = simple_noise(int_x + 1, int_z + 1);

    float i1 = cosine_interpolate(v1, v2, frac_x);
    float i2 = cosine_interpolate(v3, v4, frac_x);

    return cosine_interpolate(i1, i2, frac_z);
}

float fractal_noise(float x, float z) {
    float total = 0;
    float frequency = 1.0f;
    float amplitude = 1.0f;
    float persistence = 0.45f;
    int octaves = 5;

    for(int i = 0; i < octaves; i++) {
        total += smoothed_noise(x * frequency, z * frequency) * amplitude;
        amplitude *= persistence;
        frequency *= 2.0f;
    }
    return total;
}

GameObject create_landscape(int width, int depth) {
    GameObject landscape;

    for (int z = 0; z < depth; ++z) {
        for (int x = 0; x < width; ++x) {
            float y = fractal_noise(((float)x / (float)width) * TERRAIN_SCALE, ((float)z / (float)depth) * TERRAIN_SCALE) * TERRAIN_HEIGHT;
            landscape.vertices.push_back({{ (float)x - width/2.0f, y, (float)z - depth/2.0f }, {0.0f, 1.0f, 0.0f}});
        }
    }

    // Calculate normals
    for (int z = 0; z < depth; ++z) {
        for (int x = 0; x < width; ++x) {
            float heightL = landscape.vertices[z * width + (x > 0 ? x - 1 : x)].position.y;
            float heightR = landscape.vertices[z * width + (x < width - 1 ? x + 1 : x)].position.y;
            float heightD = landscape.vertices[(z > 0 ? z - 1 : z) * width + x].position.y;
            float heightU = landscape.vertices[(z < depth - 1 ? z + 1 : z) * width + x].position.y;

            simd::float3 normal = simd::normalize(simd::float3{heightL - heightR, 2.0f, heightD - heightU});
            landscape.vertices[z * width + x].normal = normal;
        }
    }

    for (int z = 0; z < depth - 1; ++z) {
        for (int x = 0; x < width - 1; ++x) {
            int i0 = z * width + x;
            int i1 = z * width + x + 1;
            int i2 = (z + 1) * width + x;
            int i3 = (z + 1) * width + x + 1;

            landscape.indices.push_back(i0);
            landscape.indices.push_back(i2);
            landscape.indices.push_back(i1);

            landscape.indices.push_back(i1);
            landscape.indices.push_back(i2);
            landscape.indices.push_back(i3);
        }
    }

    landscape.modelMatrix = matrix_translation(0, 0, 0);
    landscape.color = {0.3f, 0.6f, 0.2f};

    return landscape;
}

float get_terrain_height(float x, float z) {
    float noise_x = (x + LANDSCAPE_WIDTH / 2.0f) / (float)LANDSCAPE_WIDTH * TERRAIN_SCALE;
    float noise_z = (z + LANDSCAPE_DEPTH / 2.0f) / (float)LANDSCAPE_DEPTH * TERRAIN_SCALE;
    return fractal_noise(noise_x, noise_z) * TERRAIN_HEIGHT;
}

