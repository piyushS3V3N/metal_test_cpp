
#pragma once

#include "objects.hpp"

/**
 * @brief Creates a 3D landscape as a GameObject using fractal noise.
 *
 * This function generates a mesh representing a terrain with mountains and valleys.
 * The height of the terrain is determined by a fractal noise algorithm, and
 * normals are calculated for proper lighting.
 *
 * @param width The width of the landscape grid.
 * @param depth The depth of the landscape grid.
 * @return A GameObject representing the generated landscape.
 */
GameObject create_landscape(int width, int depth);

/**
 * @brief Gets the terrain height at a specific world coordinate.
 *
 * This function uses the same fractal noise algorithm as create_landscape
 * to determine the height of the terrain at a given (x, z) position.
 * Useful for camera clamping and object placement.
 *
 * @param x The x-coordinate in world space.
 * @param z The z-coordinate in world space.
 * @return The height (y-coordinate) of the terrain at the specified (x, z) position.
 */
float get_terrain_height(float x, float z);

