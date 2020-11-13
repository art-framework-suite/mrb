function(mrb_check_subdir_order)
  # Read the order determined by mrbsetenv
  set(prod_setup_file "${CMAKE_BINARY_DIR}/$ENV{MRB_PROJECT}-$ENV{MRB_PROJECT_VERSION}")
  file(READ "${prod_setup_file}" prod_setup)
  string(REPLACE "\n" ";" prod_setup "${prod_setup}")
  list(FILTER prod_setup INCLUDE REGEX "^# >> .* <<$")
  list(TRANSFORM prod_setup REPLACE "^# >> (.*) <<$" "\\1")

  # Now read the current subdirectory order.
  set(subdirs_file "${CMAKE_SOURCE_DIR}/.cmake_add_subdir")
  file(READ "${subdirs_file}" subdirs)
  string(REPLACE "\n" ";" subdirs "${subdirs}")
  list(FILTER subdirs INCLUDE REGEX "^add_subdirectory")
  list(TRANSFORM subdirs REPLACE "^add_subdirectory\\(([^)]+)\\).*$" "\\1")

  # Compare and complain.
  if (NOT "${subdirs}" STREQUAL "${prod_setup}")
    message(FATAL_ERROR "\
Current CMake subdirectory inclusion order is not consistent with current packages \
and their interdependencies.
Please run \"mrb uc\" to regenerate \${MRB_SOURCE}/CMakeLists.txt with \
subdirectories listed for inclusion in the correct order.\
")
  endif()
endfunction()
