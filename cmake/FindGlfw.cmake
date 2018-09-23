#
# Try to find GLFW library and include path.
# Once done this will define
#
# GLFW_FOUND - system has GLFW
# GLFW_INCLUDE_DIR - the GLFW include directories
# GLFW_LIBRARY - link these to use GLFW
# 

if(GLFW_INCLUDE_DIR AND GLFW_LIBRARY)
    set(GLFW_FIND_QUIETLY TRUE)
endif(GLFW_INCLUDE_DIR AND GLFW_LIBRARY)

IF (WIN32)
    FIND_PATH( GLFW_INCLUDE_DIR GLFW/glfw3.h
		$ENV{PROGRAMFILES}/GLFW/include
		${CMAKE_SOURCE_DIR}/src/nvgl/glfw/include
		DOC "The directory where GLFW/glfw3.h resides")
	FIND_LIBRARY( GLFW_LIBRARY
		NAMES glfw GLFW glfw32 glfw32s
		PATHS
		$ENV{PROGRAMFILES}/GLFW/lib
		${CMAKE_SOURCE_DIR}/src/nvgl/glfw/bin
		${CMAKE_SOURCE_DIR}/src/nvgl/glfw/lib
		DOC "The GLFW library")
ELSE (WIN32)
    FIND_PATH( GLFW_INCLUDE_DIR GLFW/glfw3.h
		/usr/include
		/usr/local/include
		/sw/include
		/opt/local/include
		DOC "The directory where GLFW/glfw3.h resides")
	FIND_LIBRARY( GLFW_LIBRARY
		NAMES GLFW glfw
		PATHS
		/usr/lib32
		/usr/lib
		/usr/local/lib32
		/usr/local/lib
		/sw/lib
		/opt/local/lib
		DOC "The GLFW library")
ENDIF (WIN32)

# handle the QUIETLY and REQUIRED arguments and set GLFW_FOUND to TRUE if 
# all listed variables are TRUE
include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(GLFW DEFAULT_MSG GLFW_LIBRARY GLFW_INCLUDE_DIR)

mark_as_advanced(GLFW_LIBRARY GLFW_INCLUDE_DIR)

