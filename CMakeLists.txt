#
#  cetbuildtools/CMakeLists.txt
#
#  CMake build file for cetbuildtools
#  This simply copies files into an install directory - there is no build
#
#  install steps:
#  cd /path/to/build/directory
#  cmake [-DCMAKE_INSTALL_PREFIX=/install/path] /path/to/mrb
#  make install
#  make package (tar file for ups)

CMAKE_MINIMUM_REQUIRED (VERSION 2.8)

PROJECT (mrb)
set (product mrb)
set (version v1_13_02)

# Throw a fatal error if cmake is invoked from within the source code directory tree
string(COMPARE EQUAL "${CMAKE_SOURCE_DIR}" "${CMAKE_BINARY_DIR}" in_source)
string( REGEX MATCH "${CMAKE_SOURCE_DIR}/" in_source_subdir "${CMAKE_BINARY_DIR}")
if (in_source OR in_source_subdir)
message(FATAL_ERROR "
ERROR: In source builds of this project are not allowed.
A separate build directory is required.
Please create one and run cmake from the build directory.
Also note that cmake has just added files to your source code directory.
We suggest getting a new copy of the source code.
Otherwise, delete `CMakeCache.txt' and the directory `CMakeFiles'.
")
endif ()

# parse the version string
STRING( REGEX REPLACE "^[v](.*)[_](.*)[_](.*)$" "\\1" VERSION_MAJOR "${version}" )
STRING( REGEX REPLACE "^[v](.*)[_](.*)[_](.*)$" "\\2" VERSION_MINOR "${version}" )
STRING( REGEX REPLACE "^[v](.*)[_](.*)[_](.*)$" "\\3" VERSION_PATCH "${version}" )

# a few more definitions
set( UPSFLAVOR NULL )

# source code
add_subdirectory(bin)
add_subdirectory(templates)
add_subdirectory(ups)

# packaging utility
set( CPACK_PACKAGE_VERSION_MAJOR ${VERSION_MAJOR} )
set( CPACK_PACKAGE_VERSION_MINOR ${VERSION_MINOR} )
set( CPACK_PACKAGE_VERSION_PATCH ${VERSION_PATCH} )
set( CPACK_INCLUDE_TOPLEVEL_DIRECTORY 0 )
set( CPACK_GENERATOR TBZ2 )
set( CPACK_PACKAGE_NAME ${product} )
set( PACKAGE_BASENAME noarch )
set( CPACK_SYSTEM_NAME ${PACKAGE_BASENAME} )
include(CPack)

