configure_file(local_setup.in local_setup @ONLY)
configure_file(local_mid.in local_mid @ONLY )

install(FILES CMakeLists.txt.main
	dbconfig
	${CMAKE_CURRENT_BINARY_DIR}/local_setup
	${CMAKE_CURRENT_BINARY_DIR}/local_mid
  DESTINATION templates)

add_subdirectory(product)
