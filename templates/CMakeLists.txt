
CONFIGURE_FILE ( ${CMAKE_CURRENT_SOURCE_DIR}/local_setup.in
                 ${CMAKE_CURRENT_BINARY_DIR}/local_setup @ONLY )

INSTALL (FILES CMakeLists.txt.master
               dependency_list
	       ${CMAKE_CURRENT_BINARY_DIR}/local_setup
	       setEnv
         DESTINATION ${product}/${version}/templates )

add_subdirectory(product)
