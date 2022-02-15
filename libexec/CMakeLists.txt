project_variable(CPAN_DIR ${${CETMODULES_CURRENT_PROJECT_NAME}_EXEC_PREFIX}/CPAN)
project_variable(LIBEXEC_DIR CONFIG ${CMAKE_INSTALL_LIBEXECDIR})

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

if (WANT_UPS)
  set(cpan_tmp
    "${PROJECT_BINARY_DIR}/${${CETMODULES_CURRENT_PROJECT_NAME}_EXEC_PREFIX}/.cpan/tmp")
  add_custom_command(OUTPUT "${cpan_tmp}/CPAN.stamp"
    COMMAND ${CMAKE_COMMAND} -E env
    MODULES_PERL5LIB=${CMAKE_CURRENT_BINARY_DIR}:${CMAKE_CURRENT_SOURCE_DIR}
    ${cetmodules_LIBEXEC_DIR}/bootstrap-perl-env
    "${CMAKE_CURRENT_BINARY_DIR}" "${CMAKE_CURRENT_SOURCE_DIR}"
    DEPFILE "${cpan_tmp}/CPAN.d"
    COMMENT "Obtain Perl prerequisites for ${CETMODULES_CURRENT_PROJECT_NAME}"
    WORKING_DIRECTORY "${PROJECT_BINARY_DIR}"
    VERBATIM)
  add_custom_target(perl-prereq ALL DEPENDS "${cpan_tmp}/CPAN.stamp" VERBATIM)
  # Bundle required Perl modules.
  install(DIRECTORY ${PROJECT_BINARY_DIR}/${${CETMODULES_CURRENT_PROJECT_NAME}_CPAN_DIR}/
    DESTINATION ${${CETMODULES_CURRENT_PROJECT_NAME}_CPAN_DIR}
    USE_SOURCE_PERMISSIONS
    )
endif()

install(DIRECTORY ${cetmodules_LIBEXEC_DIR}/
  DESTINATION  ${${CETMODULES_CURRENT_PROJECT_NAME}_LIBEXEC_DIR}
  FILES_MATCHING PATTERN "*.pm" PATTERN "Migrate" EXCLUDE)

install(FILES ${install_files}
  DESTINATION ${${PROJECT_NAME}_LIBEXEC_DIR})
