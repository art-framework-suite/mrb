cmake_minimum_required(VERSION 3.19.6...3.20 FATAL_ERROR)

set(MRB_MIN_CETMODULES_VERSION 2.31.00)
set(${MRB_MIN_INTERNAL_CETMODULES_VERSION} 3.03.02)
find_package(cetmodules ${MRB_MIN_INTERNAL_CETMODULES_VERSION})

###########################
# Project information.
project(mrb LANGUAGES NONE)

# Version handling.
set(${PROJECT_NAME}_CMAKE_PROJECT_VERSION_STRING 6.01.00)
set(${PROJECT_NAME}_EXTENDED_VERSION_SEMANTICS TRUE)

# Installed file locations.
list(APPEND ${PROJECT_NAME}_ADD_ARCH_DIRS CPAN_DIR)
list(APPEND ${PROJECT_NAME}_ADD_NOARCH_DIRS BIN_DIR LIBEXEC_DIR)
set(mrb_CONFIG_OUTPUT_ROOT_DIR share)
set(${PROJECT_NAME}_FHICL_DIR "") # Don't need.
set(${PROJECT_NAME}_INCLUDE_DIR "") # Don't need.
set(${PROJECT_NAME}_LIBRARY_DIR "") # Don't need.

# No tests.
set(BUILD_TESTING OFF)
####################################

# Basic build environment
include(CetCMakeEnv)
cet_cmake_env()

# Make modules available to downstream packages, even though we don't
# need them ourselves.
cet_cmake_module_directories(NO_LOCAL Modules)

####################################
# Build components.
add_subdirectory(bin)
add_subdirectory(config)
add_subdirectory(libexec)
add_subdirectory(templates)
add_subdirectory(Modules)
####################################

cet_cmake_config()
