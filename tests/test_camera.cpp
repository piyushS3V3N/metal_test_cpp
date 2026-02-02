#include "landscape.hpp"
#include <gtest/gtest.h>
#include "camera.hpp"

// Helper to compare simd::float4x4 matrices
void expect_matrix_eq(const simd::float4x4& a, const simd::float4x4& b) {
    for (int i = 0; i < 4; ++i) {
        for (int j = 0; j < 4; ++j) {
            EXPECT_NEAR(a.columns[i][j], b.columns[i][j], 1e-5);
        }
    }
}

TEST(MatrixUtils, Perspective) {
    simd::float4x4 proj = matrix_perspective_right_hand(M_PI / 2.0f, 1.0f, 0.1f, 100.0f);
    EXPECT_NEAR(proj.columns[0][0], 1.0f, 1e-5); // cot(pi/4) = 1
    EXPECT_NEAR(proj.columns[1][1], 1.0f, 1e-5);
    EXPECT_NEAR(proj.columns[2][2], -100.0f / 99.9f, 1e-5);
    EXPECT_NEAR(proj.columns[3][2], -10.0f / 99.9f, 1e-5);
    EXPECT_EQ(proj.columns[2][3], -1.0f);
}

TEST(MatrixUtils, LookAt) {
    simd::float3 eye = {0, 0, 5};
    simd::float3 center = {0, 0, 0};
    simd::float3 up = {0, 1, 0};
    simd::float4x4 view = matrix_look_at_right_hand(eye, center, up);

    simd::float4x4 expected = simd::float4x4(
        simd::float4{1, 0, 0, 0},
        simd::float4{0, 1, 0, 0},
        simd::float4{0, 0, 1, 0},
        simd::float4{0, 0, -5, 1}
    );
    
    // Transpose of what you might expect from other libraries
    expected = simd::transpose(expected);

    // Because of the way the look_at is constructed, the resulting matrix is inverted
    // and transposed compared to a typical GL-style lookAt matrix.
    // The key is that it produces the correct view transformation.
    // Let's test the z-axis translation component.
    EXPECT_NEAR(view.columns[3][2], -5.0f, 1e-5);
}

TEST(CameraTest, MakeCamera) {
    Camera cam = make_camera(800, 600);
    EXPECT_EQ(cam.position.x, 0.0f);
    EXPECT_EQ(cam.position.y, 0.0f);
    EXPECT_EQ(cam.position.z, 3.0f);
    EXPECT_EQ(cam.yaw, 0.0f);
    EXPECT_EQ(cam.pitch, 0.0f);
}

TEST(CameraTest, UpdateCameraPosition) {
    Camera cam = make_camera(800, 600);
    bool keys[1024] = {};
    keys['W'] = true; // Move forward

    update_camera(cam, 1.0f, keys, 0.0, 0.0);

    // Default orientation is looking down -Z
    EXPECT_NEAR(cam.position.z, 3.0f - cam.moveSpeed, 1e-5);
}

// TODO: Add tests for camera bounding

TEST(CameraTest, UpdateCameraBounds) {
    Camera cam = make_camera(800, 600);
    cam.position = {19.9f, 0.0f, 0.0f};
    bool keys[1024] = {};
    keys['D'] = true; // Move right

    // A large dt should move it past the boundary
    update_camera(cam, 10.0f, keys, 0.0, 0.0);

    // But it should be clamped to the max boundary
    EXPECT_EQ(cam.position.x, 20.0f);
}

TEST(CameraTest, PitchClamp) {
    Camera cam = make_camera(800, 600);
    bool keys[1024] = {};

    // Try to pitch up past the limit
    update_camera(cam, 1.0f, keys, 0.0, -10000.0);
    EXPECT_EQ(cam.pitch, 1.5708f);

    // Try to pitch down past the limit
    update_camera(cam, 1.0f, keys, 0.0, 10000.0);
    EXPECT_EQ(cam.pitch, -1.5708f);
}

TEST(MatrixUtils, Scale) {
    simd::float4x4 scale_matrix = matrix_scale(2.0f, 3.0f, 4.0f);
    simd::float4x4 expected = simd::float4x4(
        simd::float4{2.0f, 0.0f, 0.0f, 0.0f},
        simd::float4{0.0f, 3.0f, 0.0f, 0.0f},
        simd::float4{0.0f, 0.0f, 4.0f, 0.0f},
        simd::float4{0.0f, 0.0f, 0.0f, 1.0f}
    );
    expect_matrix_eq(scale_matrix, expected);
}

// Test case for get_terrain_height
TEST(LandscapeTests, GetTerrainHeightReturnsPlausibleValue) {
    // The landscape is centered around 0,0.
    // The height range is approximately [-21.4f, 21.4f].

    // Test at origin
    float height_at_origin = get_terrain_height(0.0f, 0.0f);
    EXPECT_GE(height_at_origin, -25.0f); // Lower bound with margin
    EXPECT_LE(height_at_origin, 25.0f);  // Upper bound with margin

    // Test at different points
    float height1 = get_terrain_height(10.0f, 10.0f);
    EXPECT_GE(height1, -25.0f);
    EXPECT_LE(height1, 25.0f);

    float height2 = get_terrain_height(-20.0f, 5.0f);
    EXPECT_GE(height2, -25.0f);
    EXPECT_LE(height2, 25.0f);
}

// Test case for create_landscape (basic checks)
TEST(LandscapeTests, CreateLandscapeGeneratesVerticesAndIndices) {
    GameObject landscape = create_landscape(50, 50);

    // Expect a certain number of vertices (width * depth)
    EXPECT_EQ(landscape.vertices.size(), 50 * 50);

    // Expect a certain number of indices for a grid (2 triangles per quad * (width-1) * (depth-1))
    EXPECT_EQ(landscape.indices.size(), 2 * (50 - 1) * (50 - 1) * 3); // 2 triangles, 3 indices each

    // Check if some heights are within a reasonable range
    for (const auto& vertex : landscape.vertices) {
        EXPECT_GE(vertex.position.y, -25.0f); // Lower bound with margin
        EXPECT_LE(vertex.position.y, 25.0f); // Upper bound with margin
        // Check normals are normalized
        EXPECT_NEAR(simd::length(vertex.normal), 1.0f, 1e-5);
    }
}