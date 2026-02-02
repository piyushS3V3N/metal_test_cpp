# OpenWorld Simulation

This project implements a basic 3D simulation environment using Metal and GLFW, featuring a procedurally generated landscape, simple objects (trees, rocks), and a free-look camera. It leverages Objective-C++ for Metal integration and C++ for core logic.

## Features

*   **Procedurally Generated Terrain:** A mountainous landscape generated using fractal noise, with height-based coloring (grass, rock, snow).
*   **Basic Lighting:** Simple diffuse lighting applied to all objects.
*   **Simple Objects:** Trees and rocks placed on the terrain.
*   **Free-Look Camera:** Controllable camera with mouse-look and keyboard movement (W, A, S, D, Space, C).
*   **Terrain Collision:** The camera is clamped to stay above the terrain.
*   **ImGui Integration:** A simple ImGui overlay for controls display.
*   **Doxygen Documentation:** API documentation can be generated.
*   **Unit Tests:** Google Test framework integrated for core logic testing.

## Build Instructions

The project uses CMake for its build system.

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/your-repo/metal_test_cpp.git
    cd metal_test_cpp
    ```
    (Note: Replace `https://github.com/your-repo/metal_test_cpp.git` with the actual repository URL if different.)

2.  **Create a build directory and configure CMake:**
    ```bash
    mkdir build
    cd build
    cmake ..
    ```

3.  **Build the project:**
    ```bash
    make
    ```
    This will compile the main application (`glfw_metal`), the unit tests (`run_tests`), and the Metal shaders (`shaders.metallib`).

## Running the Application

After a successful build, you can run the simulation:

```bash
./build/glfw_metal
```

### Controls

*   **Move:** `W` (forward), `S` (backward), `A` (left), `D` (right).
*   **Vertical Movement:** `Space` (up), `C` (down).
*   **Look:** Mouse movement.
*   **Toggle Cursor Lock:** `Tab` (toggles mouse input and display of ImGui window).
*   **Exit:** `Esc`.

## Running Tests

To execute the unit tests:

```bash
./build/run_tests
```

## Generating Documentation

If Doxygen is installed, you can generate the API documentation:

```bash
cd build
make doxygen
```
The generated documentation will be located in `docs/html/index.html`. You can directly open this file in your web browser.

[View Doxygen Documentation](docs/html/index.html)

## Dependencies

*   **macOS:** Development is on macOS due to Metal framework.
*   **Xcode Command Line Tools:** Provides `metal` and `metallib` compilers, `xcrun`.
*   **CMake:** Build system.
*   **GLFW:** For windowing and input. (Included as a `find_package` dependency).
*   **imgui:** Immediate-mode GUI library. (Included as a `third_party` submodule).
*   **googletest:** Unit testing framework. (Included as a `third_party` submodule).
*   **simd:** Apple's header-only SIMD library for math types (implicitly available on macOS).