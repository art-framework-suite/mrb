
INSTALL (FILES CMakeLists.txt_src
	       CMakeLists.txt_test
	       CMakeLists.txt_top
	       CMakeLists.txt_top_noflav
	       CMakeLists.txt_ups
	       product-config.cmake.in.template
	       product_deps
	       product_deps_noflav
	       setup_deps.template
	       setup_for_development
	       setup_for_development_noflav
         DESTINATION ${product}/${version}/templates/product )
