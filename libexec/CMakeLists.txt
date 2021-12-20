project_variable(CPAN_DIR CONFIG CPAN)
project_variable(LIBEXEC_DIR CONFIG ${CMAKE_INSTALL_LIBEXECDIR})

install(DIRECTORY ${cetmodules_CPAN_DIR}/
  DESTINATION ${${CETMODULES_CURRENT_PROJECT_NAME}_CPAN_DIR})
file(COPY ${cetmodules_CPAN_DIR}
  DESTINATION ../${${CETMODULES_CURRENT_PROJECT_NAME}_CPAN_DIR}/..)

configure_file(setup_products.in setup_products @ONLY)
cet_script(
	${CMAKE_CURRENT_BINARY_DIR}/setup_products
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
	pullDep.py
	svnCheckout.sh
	updateDepsCM.sh
	updateDepsPV.sh
	updateSource.sh
	zapBuild.sh
	zapDist.sh
	zapInstall.sh
  ${cetmodules_LIBEXEC_DIR}/cet_lock
  add_to_cmake.sh
  checkBuildDir.sh
  DESTINATION ${${PROJECT_NAME}_LIBEXEC_DIR})

set(mrb_files
	shell_independence
	unset_shell_independence
  mrbSetEnv
  setup_local_products
  )

foreach(file IN LISTS mrb_files)
  configure_file("${file}" "${file}" COPYONLY)
  list(APPEND install_files "${CMAKE_CURRENT_BINARY_DIR}/${file}")
endforeach()

set(cetmodules_files
  fail
  message_functions.sh
  pass
  )

foreach (file IN LISTS cetmodules_files)
  configure_file(${cetmodules_LIBEXEC_DIR}/${file} . COPYONLY)
  list(APPEND install_files "${CMAKE_CURRENT_BINARY_DIR}/${file}")
endforeach()

file(COPY ${cetmodules_LIBEXEC_DIR}
  DESTINATION ../${${CETMODULES_CURRENT_PROJECT_NAME}_LIBEXEC_DIR}/..
  FILES_MATCHING PATTERN "*.pm" PATTERN "Migrate" EXCLUDE)

install(DIRECTORY ${cetmodules_LIBEXEC_DIR}/
  DESTINATION  ${${CETMODULES_CURRENT_PROJECT_NAME}_LIBEXEC_DIR}
  FILES_MATCHING PATTERN "*.pm" PATTERN "Migrate" EXCLUDE)

install(FILES ${install_files}
  DESTINATION ${${PROJECT_NAME}_LIBEXEC_DIR})
