cmake_minimum_required(VERSION 3.10)
project(linkpc LANGUAGES CXX)

set(BINARY_NAME "linkpc")

cmake_policy(SET CMP0063 NEW)

set(CMAKE_INSTALL_RPATH "$ORIGIN/lib")

# Configure build options.
if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  set(CMAKE_BUILD_TYPE "Debug" CACHE
    STRING "Choose the type of build, options are: Debug Profile Release."
    FORCE)
endif()

# Application build
add_executable(${BINARY_NAME}
  "my_application.cc"
)

apply_standard_settings(${BINARY_NAME})
target_compile_definitions(${BINARY_NAME} PRIVATE "APPLICATION_ID=\"net.linkpc.client\"")
