cmake_minimum_required(VERSION 2.8)
project(DBoW2)

option(BUILD_DBoW2   "Build DBoW2"            ON)
option(BUILD_Demo    "Build demo application" OFF)

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  set(CMAKE_BUILD_TYPE Release CACHE STRING "Choose the type of build." FORCE)
  set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS "Debug" "Release"
    "MinSizeRel" "RelWithDebInfo")
endif()

if(MSVC)
  if(CMAKE_CXX_FLAGS MATCHES "/W[0-4]")
    string(REGEX REPLACE "/W[0-4]" "/W4" CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS}")
  else()
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /W4")
  endif()
elseif(CMAKE_COMPILER_IS_GNUCC OR CMAKE_COMPILER_IS_GNUCXX)
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -pedantic")
endif()

set(HDRS
  include/DBoW2/BowVector.h           include/DBoW2/FBrief.h
  include/DBoW2/QueryResults.h        include/DBoW2/TemplatedDatabase.h   include/DBoW2/FORB.h
  include/DBoW2/DBoW2.h               include/DBoW2/FClass.h              include/DBoW2/FeatureVector.h
  include/DBoW2/ScoringObject.h       include/DBoW2/TemplatedVocabulary.h)
set(SRCS 
  src/BowVector.cpp     src/FBrief.cpp        src/FORB.cpp
  src/FeatureVector.cpp src/QueryResults.cpp  src/ScoringObject.cpp)

set(DEPENDENCY_DIR ${CMAKE_CURRENT_BINARY_DIR}/dependencies)
set(DEPENDENCY_INSTALL_DIR ${DEPENDENCY_DIR}/install)

find_package(OpenCV REQUIRED)
include_directories(${OpenCV_INCLUDE_DIRS})

find_package(Boost REQUIRED)
include_directories(${Boost_INCLUDE_DIR})


message("DLib library found, using it from the system")
include_directories(${DLib_INCLUDE_DIRS})
add_custom_target(Dependencies)

if(BUILD_DBoW2)
  add_library(${PROJECT_NAME} SHARED ${SRCS})
  target_include_directories(${PROJECT_NAME} PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include> 
  $<INSTALL_INTERFACE:include>
  PRIVATE
    include/DBoW2
  )
  set_target_properties(${PROJECT_NAME} PROPERTIES DEBUG_POSTFIX "_d")
  add_dependencies(${PROJECT_NAME} Dependencies)
  target_link_libraries(${PROJECT_NAME} PUBLIC ${OpenCV_LIBS} PRIVATE ${DLib_LIBS})
  target_compile_definitions(${PROJECT_NAME} PRIVATE DBOW_EXPORT)
endif(BUILD_DBoW2)

if(BUILD_Demo)
  add_executable(demo demo/demo.cpp)
  target_link_libraries(demo ${PROJECT_NAME} ${OpenCV_LIBS} ${DLib_LIBS})
  file(COPY demo/images DESTINATION ${CMAKE_BINARY_DIR}/)
endif(BUILD_Demo)
if(BUILD_DBoW2)
install(TARGETS ${PROJECT_NAME} EXPORT "${PROJECT_NAME}Targets")
install(EXPORT "${PROJECT_NAME}Targets"
    FILE "${PROJECT_NAME}Targets.cmake"
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/DBoW2
)
write_basic_package_version_file(
  "${PROJECT_NAME}ConfigVersion.cmake"
  VERSION 0.1
  COMPATIBILITY AnyNewerVersion
)
install(DIRECTORY include/DBoW2 DESTINATION ${CMAKE_INSTALL_PREFIX}/include/DBoW2)
install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/src/DBoW2Config.cmake" "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}ConfigVersion.cmake"
  DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/DBoW2)
install(DIRECTORY ${DEPENDENCY_INSTALL_DIR}/ DESTINATION ${CMAKE_INSTALL_PREFIX} OPTIONAL)
endif()
