cmake_minimum_required(VERSION 3.20)

project(glfw_metal LANGUAGES CXX OBJCXX)

# ---- C++ / ObjC++ standard ----
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_OBJCXX_STANDARD 17)
set(CMAKE_OBJCXX_STANDARD_REQUIRED ON)

# ---- Dependencies ----
find_package(glfw3 CONFIG REQUIRED)

# ---- Sources ----
set(SRC_FILES
    src/main.mm
    src/metal_context.mm
    src/metal_cpp_impl.cpp
    src/cube.cpp
    src/landscape.cpp
)

add_executable(glfw_metal ${SRC_FILES})

# ---- Include paths ----
target_include_directories(glfw_metal PRIVATE
    ${CMAKE_SOURCE_DIR}/metal-cpp
    ${CMAKE_SOURCE_DIR}/src
)

# ---- ObjC ARC ----
target_compile_options(glfw_metal PRIVATE
    -fobjc-arc
)

# ---- Apple frameworks ----
target_link_libraries(glfw_metal PRIVATE
    glfw
    imgui
    "-framework Metal"
    "-framework QuartzCore"
    "-framework Foundation"
)

# ---- ImGui ----
file(GLOB IMGUI_SRC
    "third_party/imgui/*.cpp"
    "third_party/imgui/backends/imgui_impl_glfw.cpp"
    "third_party/imgui/backends/imgui_impl_metal.mm"
)

add_library(imgui STATIC ${IMGUI_SRC})

target_link_libraries(imgui PRIVATE glfw)


target_include_directories(imgui PUBLIC
    "${CMAKE_SOURCE_DIR}/metal-cpp"
    "third_party/imgui"
    "third_party/imgui/backends"
)

target_compile_definitions(imgui PRIVATE
    IMGUI_IMPL_METAL_CPP
)


# ---- Metal shader compilation ----
set(METAL_SRC ${CMAKE_SOURCE_DIR}/src/shaders.metal)
set(METAL_AIR ${CMAKE_BINARY_DIR}/shaders.air)
set(METAL_LIB ${CMAKE_BINARY_DIR}/shaders.metallib)

add_custom_command(
    OUTPUT ${METAL_LIB}
    COMMAND xcrun -sdk macosx metal -c ${METAL_SRC} -o ${METAL_AIR}
    COMMAND xcrun -sdk macosx metallib ${METAL_AIR} -o ${METAL_LIB}
    DEPENDS ${METAL_SRC}
    COMMENT "Compiling Metal shaders"
)

add_custom_target(metal_shaders ALL
    DEPENDS ${METAL_LIB}
)

add_dependencies(glfw_metal metal_shaders)

# ---- Copy metallib next to executable ----
add_custom_command(TARGET glfw_metal POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
    ${METAL_LIB}
    $<TARGET_FILE_DIR:glfw_metal>
)

# ---- Unit Testing ----
enable_testing()

add_subdirectory(third_party/googletest)

add_executable(run_tests
    tests/test_camera.cpp
    src/landscape.cpp
)

target_link_libraries(run_tests PRIVATE gtest_main)

target_include_directories(run_tests PRIVATE
    ${CMAKE_SOURCE_DIR}/src
)

add_test(NAME unit_tests COMMAND run_tests)



# ---- Documentation ----

find_package(Doxygen)

if (DOXYGEN_FOUND)

    add_custom_target(doxygen

        COMMAND ${DOXYGEN_EXECUTABLE} ${CMAKE_SOURCE_DIR}/Doxyfile

        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}

        COMMENT "Generating API documentation with Doxygen"

        VERBATIM)

endif()