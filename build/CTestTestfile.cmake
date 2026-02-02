# CMake generated Testfile for 
# Source directory: /Users/piyushparashar/Project/metal_test_cpp
# Build directory: /Users/piyushparashar/Project/metal_test_cpp/build
# 
# This file includes the relevant testing commands required for 
# testing this directory and lists subdirectories to be tested as well.
add_test([=[unit_tests]=] "/Users/piyushparashar/Project/metal_test_cpp/build/run_tests")
set_tests_properties([=[unit_tests]=] PROPERTIES  _BACKTRACE_TRIPLES "/Users/piyushparashar/Project/metal_test_cpp/CMakeLists.txt;110;add_test;/Users/piyushparashar/Project/metal_test_cpp/CMakeLists.txt;0;")
subdirs("third_party/googletest")
