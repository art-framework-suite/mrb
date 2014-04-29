
INSTALL ( PROGRAMS add_to_cmake.sh
		   copy_files_to_srcs.sh
		   define_local
		   edit_product_deps
		   findCetBuild
		   get_setup_list.sh
		   gitCheckout.sh
		   mrb
		   newDev.sh
		   newProduct.sh
		   mrbSetEnv
		   setup_products
		   svnCheckout.sh
		   updateDepsCM.sh
		   updateDepsPV.sh
		   zapBuild.sh
          DESTINATION ${product}/${version}/bin )

INSTALL (FILES mrb_parse_deps.pm
               setup_local_products
		   shell_independence
		   unset_shell_independence
         DESTINATION ${product}/${version}/bin )
