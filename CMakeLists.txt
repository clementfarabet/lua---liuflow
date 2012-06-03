CMAKE_MINIMUM_REQUIRED(VERSION 2.6 FATAL_ERROR)
CMAKE_POLICY(VERSION 2.6)
FIND_PACKAGE(Torch REQUIRED)

SET(src liuflow.cpp
        GaussianPyramid.cpp
        GaussianPyramid.h
        Image.h
        ImageIO.h
        ImageProcessing.h
        OpticalFlowCode.cpp
        OpticalFlow.h
        project.h)

SET(luasrc init.lua
           img1.jpg
           img2.jpg
           legend.png)

SET(QT_MIN_VERSION "4.3.0")
FIND_PACKAGE(Qt4)

IF (QT4_FOUND)
  INCLUDE_DIRECTORIES (${QT_INCLUDES})
  INCLUDE (${QT_USE_FILE})
  LINK_DIRECTORIES (${QT_LIBRARY_DIR})
  ADD_TORCH_PACKAGE(liuflow "${src}" "${luasrc}" "Vision")
  TARGET_LINK_LIBRARIES(liuflow luaT TH ${QT_LIBRARIES})
ENDIF (QT4_FOUND)
