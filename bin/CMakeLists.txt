
INSTALL ( PROGRAMS add_to_cmake.sh
		   copy_files_to_srcs.sh
		   define_local
		   findCetBuild
		   get_setup_list.sh
		   gitCheckout.sh
		   mrb
		   newDev.sh
		   newProduct.sh
		   setEnv.sh
		   setup_products
		   svnCheckout.sh
		   tagit.sh
		   updateDepsCM.sh
		   updateDepsPD.sh
		   update_deps_productdeps.py
		   zapBuild.sh
          DESTINATION ${product}/${version}/bin )

INSTALL (FILES mrb_parse_deps.pm
               setup_local_products
         DESTINATION ${product}/${version}/bin )
