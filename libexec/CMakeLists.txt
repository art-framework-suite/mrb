project_variable(LIBEXEC_DIR CONFIG ${CMAKE_INSTALL_LIBEXECDIR})

configure_file(setup_products.in setup_products @ONLY)
cet_script(add_to_cmake.sh
  checkBuildDir.sh
	changeQual.sh
	copy_dependency_database.sh
	copy_files_to_srcs.sh
	edit_cmake
	edit_product_deps
	edit_product_deps_qual
	findDir.sh
	get_setup_list.sh
	gitCheckout
	makeDep.py
	makePackage.sh
	newDev.sh
	newProduct.sh
	mrbSetEnv
	pullDep.py
	${CMAKE_CURRENT_BINARY_DIR}/setup_products
	svnCheckout.sh
	updateDepsCM.sh
	updateDepsPV.sh
	updateSource.sh
	zapBuild.sh
	zapDist.sh
	zapInstall.sh
  DESTINATION ${${PROJECT_NAME}_LIBEXEC_DIR})

cet_localize_pv(cetmodules LIBEXEC_DIR)
install(FILES
	shell_independence
	unset_shell_independence
  ${cetmodules_LIBEXEC_DIR}/fail
  ${cetmodules_LIBEXEC_DIR}/parse_deps.pm
  ${cetmodules_LIBEXEC_DIR}/pass
  setup_local_products
  DESTINATION ${${PROJECT_NAME}_LIBEXEC_DIR})
