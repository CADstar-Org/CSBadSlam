if(MSVC)
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /bigobj")
endif()

if (CMAKE_CUDA_COMPILER)
  set(WITH_REALSENSE OFF CACHE BOOL "Enable Realsense2 Support")
  set(WITH_K4A OFF CACHE BOOL "Enable Kinect4Azure Support")

  # Make CMake find the Find<Package>.cmake files in the cmake subdirectory.
  set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
  
  #DLib dependency (automatically downloaded from github)
  include(FetchContent)
  FetchContent_Declare(DLib
    GIT_REPOSITORY https://github.com/dorian3d/DLib.git
    GIT_TAG 16ceae3e5e6bfcc67d52297f1b0ce9c0072bb0d4
  )
  FetchContent_MakeAvailable(DLib)
  #Do not install the DLib target
  if(IS_DIRECTORY "${DLib_SOURCE_DIR}")
    set_property(DIRECTORY ${DLib_SOURCE_DIR} PROPERTY EXCLUDE_FROM_ALL YES)
  endif()

  # Dependencies
  find_package(SuiteSparse REQUIRED)
  find_package(g2o REQUIRED)
  find_package(OpenGL REQUIRED)

  # Cross-platform threading. See:
  # https://cmake.org/cmake/help/latest/module/FindThreads.html
  find_package(Threads REQUIRED)
  find_package(GTest REQUIRED) # https://stackoverflow.com/questions/41315739/vcpkg-does-not-work-for-google-test
  enable_testing()

  if (UNIX)
    find_package(X11 REQUIRED)
  endif()
  

  add_subdirectory(third_party/DBoW2)
  set_target_properties(DBoW2 Dependencies PROPERTIES FOLDER "badslam/third_party/DBoW2")

  find_package(opengv CONFIG REQUIRED)
  
  # Optional, only required for live RealSense camera support
  if(WITH_REALSENSE)
	find_package(realsense2)
  endif()
  # Optional, only required for live Azure Kinect camera support
  if(WITH_K4A)
    if (WIN32)
    # Use a custom find script in the cmake subdirectory since the K4A SDK does
    # not seem to ship cmake files on Windows
    find_package(K4A)
    else()
      # On Linux, use the SDK-provided CMake files
      find_package(k4a)
      find_package(k4arecord)
    endif()
  endif()
  # Optional, only required for live Structure Core camera support
  find_package(Structure)

  set(CMAKE_CUDA_STANDARD 14)
  set(CMAKE_CUDA_STANDARD_REQUIRED ON)
  
  # CSBadSlam (used by both the executable and the unit test).
  file(GLOB BAD_SLAM_SRC
    "src/badslam/*.h"
    "src/badslam/*.cc"
    "src/badslam/*.cu"
    "src/badslam/*.cuh"
    "resources/*.qrc"
  )
  list(REMOVE_ITEM
    BAD_SLAM_SRC
    "${CMAKE_CURRENT_SOURCE_DIR}/src/badslam/main.cc"
  )
  add_library(CSBadSlam SHARED
    ${BAD_SLAM_SRC}
  )
  set_target_properties(CSBadSlam PROPERTIES 
  	FOLDER "badslam"
    DEBUG_POSTFIX "_d"
  )
  target_compile_options(CSBadSlam
    PUBLIC
      ${LIBVIS_WARNING_OPTIONS}
  )

    target_compile_options(CSBadSlam
      PUBLIC
        # NOTE: The -march=native was required to be able to use opengv, otherwise
        #       it would just crash when calling an opengv function. I suspect
        #       that it might be because the Eigen objects passed to opengv might
        #       be compiled to have different layouts then, but this is only a
        #       guess.
        # NOTE: g2o also needs to be built with the same setting (it defaults
        #       to not use -march=native at the moment).
        $<$<COMPILE_LANGUAGE:CUDA>:-use_fast_math>
        $<$<COMPILE_LANGUAGE:CUDA>:--expt-relaxed-constexpr>
        # NOTE: Uncomment the line below if using cuda-memcheck
        # $<$<COMPILE_LANGUAGE:CUDA>:-Xcompiler -rdynamic -lineinfo>
    )
  if (NOT MSVC)
    target_compile_options(CSBadSlam
      PUBLIC
        # NOTE: The -march=native was required to be able to use opengv, otherwise
        #       it would just crash when calling an opengv function. I suspect
        #       that it might be because the Eigen objects passed to opengv might
        #       be compiled to have different layouts then, but this is only a
        #       guess.
        # NOTE: g2o also needs to be built with the same setting (it defaults
        #       to not use -march=native at the moment).
        $<$<COMPILE_LANGUAGE:CXX>:-march=native>
	)
    else()
    target_compile_options(CSBadSlam
      PUBLIC
        $<$<COMPILE_LANGUAGE:CXX>:/fp:fast>
	)
  endif()
  target_include_directories(CSBadSlam
    PRIVATE
      src
      ${SuiteSparse_INCLUDE_DIRS}
      third_party
      ${OPENGV_INCLUDE_DIR}
  )
  if (CMAKE_CUDA_COMPILER_VERSION VERSION_LESS 11)
    target_include_directories(CSBadSlam PUBLIC
      third_party/cub-1.8.0
    )
  endif()
  if (realsense2_FOUND)
    target_compile_options(CSBadSlam
      PRIVATE
        $<$<COMPILE_LANGUAGE:CXX>:-DBAD_SLAM_HAVE_REALSENSE>
    )
  endif()

  if (WIN32)
    if (TARGET K4APrebuilt AND TARGET K4ARecordPrebuilt)
      target_link_libraries(CSBadSlam PUBLIC
        K4APrebuilt
        K4ARecordPrebuilt
      )
      target_compile_definitions(CSBadSlam PUBLIC HAVE_K4A)
    endif()
  else()
    if (TARGET k4a::k4a)
      target_link_libraries(CSBadSlam PUBLIC
        k4a::k4a
        k4a::k4arecord
      )
      target_compile_definitions(CSBadSlam PUBLIC HAVE_K4A)
    endif()
  endif()

  if(MSVC)
    target_compile_definitions(CSBadSlam PUBLIC NOMINMAX) # to get rid of max define
  endif()
  
  if (TARGET StructurePrebuilt)
    target_link_libraries(CSBadSlam PUBLIC
      StructurePrebuilt
    )
    target_compile_definitions(CSBadSlam PUBLIC HAVE_STRUCTURE)
  endif()

  target_link_libraries(CSBadSlam
    PRIVATE
      g2o::core
      g2o::types_slam3d
      g2o::solver_csparse
      g2o::csparse_extension
      ${SuiteSparse_LIBRARIES}
      g2o::stuff
      DLib
      DBoW2
      ${realsense2_LIBRARY}
      ${X11_LIBRARIES}
      ${OPENGV_LIBRARIES}
      ${OPENGL_LIBRARY}
    PUBLIC
      libvis
      libvis_cuda
      ${OpenCV_LIBS}
      Boost::boost
      Boost::filesystem
      GLEW::GLEW
  )
  install(TARGETS CSBadSlam EXPORT CSBadSlamTargets)
  install(EXPORT CSBadSlamTargets
      FILE CSBadSlamTargets.cmake
      DESTINATION lib/cmake
  )
  write_basic_package_version_file(
    "CSBadSlamConfigVersion.cmake"
    VERSION 0.1
    COMPATIBILITY AnyNewerVersion
  )
  install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/cmake/CSBadSlamConfig.cmake" "${CMAKE_CURRENT_BINARY_DIR}/CSBadSlamConfigVersion.cmake" DESTINATION lib/cmake)
  install(DIRECTORY src/ DESTINATION include/ FILES_MATCHING PATTERN "*.h" PATTERN "*.hpp" PATTERN "*.cuh")
  
  # badslam executable.
  set(BADSLAM_SRC
    src/badslam/main.cc
  )
  if(MSVC)
    list(APPEND BADSLAM_SRC resources/badslam.rc)
  endif()
  add_executable(badslam
    ${BADSLAM_SRC}
  )
  set_property(TARGET badslam PROPERTY FOLDER "badslam")
  set_property(TARGET badslam PROPERTY DEBUG_POSTFIX "_d")
  target_include_directories(badslam PRIVATE
    src
    third_party
    ${realsense_INCLUDE_DIR}
  )
  target_link_libraries(badslam PRIVATE
    CSBadSlam
    ${X11_LIBRARIES}
    ${CUDA_LIBRARIES}
  )
  
  # Unit test.
  add_executable(badslam_test
    src/badslam/test/main.cc
    src/badslam/test/test_geometry_optimization_geometric_residual.cc
    src/badslam/test/test_geometry_optimization_photometric_residual.cc
    src/badslam/test/test_intrinsics_optimization_geometric_residual.cc
    src/badslam/test/test_intrinsics_optimization_photometric_residual.cc
    src/badslam/test/test_pairwise_frame_tracking.cc
    src/badslam/test/test_pose_graph_optimizer.cc
    src/badslam/test/test_pose_optimization_geometric_residual.cc
    src/badslam/test/test_pose_optimization_photometric_residual.cc
  )
  set_property(TARGET badslam_test PROPERTY FOLDER "badslam")
  set_property(TARGET badslam_test PROPERTY DEBUG_POSTFIX "_d")
  target_include_directories(badslam_test PRIVATE
    src
    third_party
    ${CMAKE_CUDA_TOOLKIT_INCLUDE_DIRECTORIES}
  )
  target_link_libraries(badslam_test PRIVATE
    CSBadSlam
    GTest::GTest
    Threads::Threads
    ${X11_LIBRARIES}
    ${CUDA_LIBRARIES}
  )
  add_test(badslam_test
    badslam_test
  )
  
  # Installation.
  #set(CMAKE_SKIP_INSTALL_ALL_DEPENDENCY true)
  #install(TARGETS badslam DESTINATION bin)
  #if(UNIX AND NOT APPLE)
  #  install(FILES resources/badslam.desktop DESTINATION share/applications)  # $#{XDG_APPS_INSTALL_DIR}?
  #  install(FILES resources/badslam.png DESTINATION share/icons/hicolor/64x64/apps)
  #endif()
endif()
