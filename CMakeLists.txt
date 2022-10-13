cmake_minimum_required(VERSION 3.19.6...3.23 FATAL_ERROR)

set(MRB_MIN_CETMODULES_VERSION 2.31.00)
set(${MRB_MIN_INTERNAL_CETMODULES_VERSION} 3.07.00)
find_package(cetmodules ${MRB_MIN_INTERNAL_CETMODULES_VERSION})

###########################
# Project information.
project(mrb VERSION 6.07.03 LANGUAGES NONE)

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
