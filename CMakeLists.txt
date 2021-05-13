cmake_minimum_required(VERSION 3.19.6...3.20 FATAL_ERROR)

set(MRB_MIN_CETMODULES_VERSION 2.18.01)
find_package(cetmodules ${MRB_MIN_CETMODULES_VERSION})

project(mrb VERSION 5.09.01 LANGUAGES NONE)

# No tests of cetmodules.
set(BUILD_TESTING OFF)

# Other configuration.
set(${PROJECT_NAME}_NOARCH TRUE)
set(${PROJECT_NAME}_FHICL_DIR "")
set(${PROJECT_NAME}_INCLUDE_DIR "")
set(${PROJECT_NAME}_LIBRARY_DIR "")

# Basic build environment
include(CetCMakeEnv)
cet_cmake_env()

# Make modules available to downstream packages, even though we don't
# need them ourselves.
cet_cmake_module_directories(NO_LOCAL Modules)

####################################
# Build components.
add_subdirectory(bin)
add_subdirectory(libexec)
add_subdirectory(templates)
add_subdirectory(Modules)
####################################

cet_cmake_config(ARCH_INDEPENDENT)
