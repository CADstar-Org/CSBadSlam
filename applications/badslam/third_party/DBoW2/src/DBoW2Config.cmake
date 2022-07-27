include(CMakeFindDependencyMacro)
find_dependency(Boost REQUIRED)
find_dependency(OpenCV REQUIRED)
include(${CMAKE_CURRENT_LIST_DIR}/DBoW2Targets.cmake)
