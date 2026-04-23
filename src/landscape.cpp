#include "landscape.hpp"
#include "camera.hpp"
#include <cmath>

namespace {
    const int LANDSCAPE_WIDTH = 128; // Increased resolution
    const int LANDSCAPE_DEPTH = 128;
    const float TERRAIN_SCALE = 4.0f;
    const float TERRAIN_HEIGHT = 15.0f;
}

// Meticulously matched with Shader logic
float hash(int n) {
    n = (n << 13) ^ n;
    return (1.0f - ((n * (n * n * 15731 + 789221) + 1376312589) & 0x7fffffff) / 1073741824.0f);
}

float interpolate(float a, float b, float t) {
    float ft = t * 3.1415927f;
    float f = (1.0f - cosf(ft)) * 0.5f;
    return a * (1.0f - f) + b * f;
}

float noise(float x, float z) {
    int ix = (int)floorf(x);
    int iz = (int)floorf(z);
    float fx = x - ix;
    float fz = z - iz;

    float v1 = hash(ix + iz * 57);
    float v2 = hash(ix + 1 + iz * 57);
    float v3 = hash(ix + (iz + 1) * 57);
    float v4 = hash(ix + 1 + (iz + 1) * 57);

    float i1 = interpolate(v1, v2, fx);
    float i2 = interpolate(v3, v4, fx);
    return interpolate(i1, i2, fz);
}

float get_fractal_noise(float x, float z) {
    float total = 0;
    float freq = 1.0f;
    float amp = 1.0f;
    for(int i = 0; i < 6; i++) {
        total += noise(x * freq, z * freq) * amp;
        amp *= 0.5f;
        freq *= 2.0f;
    }
    return total;
}

GameObject create_landscape(int width, int depth) {
    GameObject landscape;
    float w = (float)LANDSCAPE_WIDTH;
    float d = (float)LANDSCAPE_DEPTH;

    for (int z = 0; z < LANDSCAPE_DEPTH; ++z) {
        for (int x = 0; x < LANDSCAPE_WIDTH; ++x) {
            float vx = (float)x - w/2.0f;
            float vz = (float)z - d/2.0f;
            float y = get_terrain_height(vx, vz);
            landscape.vertices.push_back({{vx, y, vz}, {0, 1, 0}});
        }
    }

    for (int z = 0; z < LANDSCAPE_DEPTH - 1; ++z) {
        for (int x = 0; x < LANDSCAPE_WIDTH - 1; ++x) {
            int i0 = z * LANDSCAPE_WIDTH + x;
            int i1 = z * LANDSCAPE_WIDTH + (x + 1);
            int i2 = (z + 1) * LANDSCAPE_WIDTH + x;
            int i3 = (z + 1) * LANDSCAPE_WIDTH + (x + 1);
            landscape.indices.push_back(i0); landscape.indices.push_back(i2); landscape.indices.push_back(i1);
            landscape.indices.push_back(i1); landscape.indices.push_back(i2); landscape.indices.push_back(i3);
        }
    }
    landscape.modelMatrix = matrix_translation(0, 0, 0);
    landscape.color = {1, 1, 1}; // Base white, colored in shader
    return landscape;
}

float get_terrain_height(float x, float z) {
    float nx = (x + 64.0f) / 128.0f * TERRAIN_SCALE;
    float nz = (z + 64.0f) / 128.0f * TERRAIN_SCALE;
    return get_fractal_noise(nx, nz) * TERRAIN_HEIGHT;
}
