
INSTALL ( PROGRAMS add_to_cmake.sh
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
		   mrb
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
          DESTINATION ${product}/${version}/bin )

INSTALL (FILES mrb_parse_deps.pm
        ssh-init.sh
        parse_deps.pm
        setup_local_products
	shell_independence
	unset_shell_independence
  DESTINATION ${product}/${version}/bin )
