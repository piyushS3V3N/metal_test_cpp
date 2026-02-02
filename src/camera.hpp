/**
 * @file camera.hpp
 * @brief Contains the Camera struct and functions for camera manipulation.
 */

#pragma once
#include <simd/simd.h>
#include <cmath>

// --- Matrix utilities ---

/**
 * @brief Creates a right-handed perspective projection matrix.
 * @param fovyRadians The field of view in radians.
 * @param aspect The aspect ratio.
 * @param nearZ The near clipping plane.
 * @param farZ The far clipping plane.
 * @return The projection matrix.
 */
simd::float4x4 matrix_perspective_right_hand(float fovyRadians, float aspect, float nearZ, float farZ);

/**
 * @brief Creates a right-handed look-at view matrix.
 * @param eye The position of the camera.
 * @param center The point to look at.
 * @param up The up vector.
 * @return The view matrix.
 */
simd::float4x4 matrix_look_at_right_hand(simd::float3 eye, simd::float3 center, simd::float3 up);

/**
 * @brief Creates a translation matrix.
 * @param tx The translation in x.
 * @param ty The translation in y.
 * @param tz The translation in z.
 * @return The translation matrix.
 */
simd::float4x4 matrix_translation(float tx, float ty, float tz);

/**
 * @brief Creates a rotation matrix around the Y axis.
 * @param angleRadians The angle of rotation in radians.
 * @return The rotation matrix.
 */
simd::float4x4 matrix_rotation_y(float angleRadians);

/**
 * @brief Creates a scale matrix.
 * @param sx The scale factor along the X-axis.
 * @param sy The scale factor along the Y-axis.
 * @param sz The scale factor along the Z-axis.
 * @return The 4x4 scale matrix.
 */
simd::float4x4 matrix_scale(float sx, float sy, float sz);



/**
 * @struct Camera
 * @brief Represents a camera in the 3D scene.
 */
struct Camera {
    simd::float3 position;      ///< The position of the camera in world space.
    float yaw = 0.0f;           ///< The yaw of the camera in radians.
    float pitch = 0.0f;         ///< The pitch of the camera in radians.
    
    float moveSpeed = 8.0f;     ///< The movement speed of the camera.
    float lookSpeed = 0.005f;   ///< The look sensitivity of the camera.

    simd::float4x4 viewMatrix;  ///< The view matrix.
    simd::float4x4 projectionMatrix; ///< The projection matrix.
};

/**
 * @brief Creates a new Camera instance.
 * @param width The width of the viewport.
 * @param height The height of the viewport.
 * @return A new Camera instance.
 */
inline Camera make_camera(int width, int height) {
    Camera cam{};
    cam.position = {0.0f, 0.0f, 3.0f};
    cam.projectionMatrix = matrix_perspective_right_hand(M_PI / 3.0f, (float)width / (float)height, 0.1f, 100.0f);
    return cam;
}

/**
 * @brief Updates the camera's state based on user input.
 * @param cam The camera to update.
 * @param dt The delta time since the last frame.
 * @param keys The state of the keyboard keys.
 * @param mouseX The current mouse X position.
 * @param mouseY The current mouse Y position.
 */
inline void update_camera(Camera& cam, float dt, bool keys[1024], double mouseX, double mouseY) {
    static double lastMouseX;
    static double lastMouseY;
    static bool firstMouse = true;

    if (firstMouse) {
        lastMouseX = mouseX;
        lastMouseY = mouseY;
        firstMouse = false;
    }
    
    float deltaX = float(mouseX - lastMouseX);
    float deltaY = float(mouseY - lastMouseY);
    
    lastMouseX = mouseX;
    lastMouseY = mouseY;
    
    cam.yaw += deltaX * cam.lookSpeed;
    cam.pitch -= deltaY * cam.lookSpeed;
    
    // Clamp pitch to prevent flipping
    if (cam.pitch > 1.5708f) cam.pitch = 1.5708f;
    if (cam.pitch < -1.5708f) cam.pitch = -1.5708f;
    
    float cos_pitch = cosf(cam.pitch);
    simd::float3 forward = simd::normalize(simd::float3{ sinf(cam.yaw) * cos_pitch, sinf(cam.pitch), -cosf(cam.yaw) * cos_pitch });
    simd::float3 right = simd::normalize(simd::cross(forward, simd::float3{0, 1, 0}));

    simd::float3 moveDir = {0, 0, 0};
    if (keys['W']) moveDir += forward;
    if (keys['S']) moveDir -= forward;
    if (keys['A']) moveDir -= right;
    if (keys['D']) moveDir += right;
    if (keys[' ']) moveDir.y += 1.0f;
    if (keys['C'] || keys['X']) moveDir.y -= 1.0f;
    
    if (simd::length(moveDir) > 0.01f) {
        cam.position += simd::normalize(moveDir) * cam.moveSpeed * dt;
    }
    
    // Clamp position to a bounding box
    simd::float3 minBounds = {-20.0f, 0.0f, -20.0f};
    simd::float3 maxBounds = {20.0f, 20.0f, 20.0f};
    cam.position = simd::clamp(cam.position, minBounds, maxBounds);

    cam.viewMatrix = matrix_look_at_right_hand(cam.position, cam.position + forward, simd::float3{0, 1, 0});
}

// --- Matrix implementations ---

inline simd::float4x4 matrix_perspective_right_hand(float fovyRadians, float aspect, float nearZ, float farZ) {
    float ys = 1.0f / tanf(fovyRadians * 0.5f);
    float xs = ys / aspect;
    float zs = farZ / (nearZ - farZ);
    return simd::float4x4(
        simd::float4{xs, 0.0f, 0.0f, 0.0f},
        simd::float4{0.0f, ys, 0.0f, 0.0f},
        simd::float4{0.0f, 0.0f, zs, -1.0f},
        simd::float4{0.0f, 0.0f, zs * nearZ, 0.0f}
    );
}

inline simd::float4x4 matrix_look_at_right_hand(simd::float3 eye, simd::float3 center, simd::float3 up) {
    simd::float3 f = simd::normalize(center - eye);
    simd::float3 s = simd::normalize(simd::cross(f, up));
    simd::float3 u = simd::cross(s, f);

    return simd::float4x4(
        simd::float4{s.x, u.x, -f.x, 0.0f},
        simd::float4{s.y, u.y, -f.y, 0.0f},
        simd::float4{s.z, u.z, -f.z, 0.0f},
        simd::float4{-simd::dot(s, eye), -simd::dot(u, eye), simd::dot(f, eye), 1.0f}
    );
}

inline simd::float4x4 matrix_translation(float tx, float ty, float tz) {
    return simd::float4x4(
        simd::float4{1.0f, 0.0f, 0.0f, 0.0f},
        simd::float4{0.0f, 1.0f, 0.0f, 0.0f},
        simd::float4{0.0f, 0.0f, 1.0f, 0.0f},
        simd::float4{tx, ty, tz, 1.0f}
    );
}

inline simd::float4x4 matrix_rotation_y(float angleRadians) {
    float c = cosf(angleRadians);
    float s = sinf(angleRadians);
    return simd::float4x4(
        simd::float4{c, 0.0f, -s, 0.0f},
        simd::float4{0.0f, 1.0f, 0.0f, 0.0f},
        simd::float4{s, 0.0f, c, 0.0f},
        simd::float4{0.0f, 0.0f, 0.0f, 1.0f}
    );
}

inline simd::float4x4 matrix_scale(float sx, float sy, float sz) {
    return simd::float4x4(
        simd::float4{sx, 0.0f, 0.0f, 0.0f},
        simd::float4{0.0f, sy, 0.0f, 0.0f},
        simd::float4{0.0f, 0.0f, sz, 0.0f},
        simd::float4{0.0f, 0.0f, 0.0f, 1.0f}
    );
}

