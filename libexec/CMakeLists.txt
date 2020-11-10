project_variable(LIBEXEC_DIR CONFIG ${CMAKE_INSTALL_LIBEXECDIR})

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
	setup_products
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
  ${cetmodules_LIBEXEC_DIR}/parse_deps.pm
  setup_local_products
	shell_independence
	unset_shell_independence
  DESTINATION ${${PROJECT_NAME}_LIBEXEC_DIR})
