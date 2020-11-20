configure_file(Mrb.cmake.in Mrb.cmake @ONLY)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/Mrb.cmake
  DESTINATION Modules)
