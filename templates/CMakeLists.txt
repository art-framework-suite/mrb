
INSTALL (FILES CMakeLists.txt.master
               dependency_list
	       local_setup
	       setEnv
         DESTINATION ${product}/${version}/templates )

add_subdirectory(product)
