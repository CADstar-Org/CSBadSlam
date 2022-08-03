include(CMakeFindDependencyMacro)
find_dependency(libvis REQUIRED PATHS "${CMAKE_CURRENT_LIST_DIR}")
include(${CMAKE_CURRENT_LIST_DIR}/libvis_cudaTargets.cmake)
