include(CMakeFindDependencyMacro)
find_dependency(libvis CONFIG REQUIRED PATHS "${CMAKE_CURRENT_LIST_DIR}/libvis")
find_dependency(libvis_cuda CONFIG  REQUIRED PATHS "${CMAKE_CURRENT_LIST_DIR}/libvis")
find_dependency(OpenCV REQUIRED)
find_dependency(opengv REQUIRED)
find_dependency(Boost REQUIRED)
find_dependency(OpenGL REQUIRED)
find_dependency(GLEW REQUIRED)

#not needed for building, but their DLLs must be located
find_dependency(g2o REQUIRED)
find_dependency(SuiteSparse REQUIRED)

include(${CMAKE_CURRENT_LIST_DIR}/DBoW2/DBoW2Config.cmake)

include(${CMAKE_CURRENT_LIST_DIR}/CSBadSlamTargets.cmake)