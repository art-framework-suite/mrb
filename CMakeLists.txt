cmake_minimum_required(VERSION 3.18.2 FATAL_ERROR)

find_package(cetmodules 2.03.00)
project(mrb VERSION 5.00.00 LANGUAGES NONE)

set(${PROJECT_NAME}_NOARCH TRUE)
set(${PROJECT_NAME}_LIBRARY_DIR "")
set(${PROJECT_NAME}_INCLUDE_DIR "")

include(CetCMakeEnv)
cet_cmake_env()

####################################
# Build components.
add_subdirectory(bin)
add_subdirectory(libexec)
add_subdirectory(templates)
####################################

cet_cmake_config(ARCH_INDEPENDENT COMPATIBILITY SameMajorVersion)
