# MRBMake

# mrb_make is a front end to art_make with all the same arguments

# Specify libraries as, for instance, Geometry instead of ${GEOMETRY}
# mrb_make will use ${GEOMETRY} if it exists
# This is needed so that you can build a single package both standalone and 
# with other packages while using the power of cmake to sort dependencies

# USAGE:
#
# mrb_make( [LIBRARY_NAME <library name>]
#           [LIB_LIBRARIES <library list>]
#           [DICT_LIBRARIES <library list>]
#           [MODULE_LIBRARIES <library list>]
#           [SERVICE_LIBRARIES <library list>]
#           [SOURCE_LIBRARIES <library list>]
#           [SUBDIRS <source subdirectory>]
#           [EXCLUDE <ignore these files>]
#           [WITH_STATIC_LIBRARY]
#           [BASENAME_ONLY] 
#           [NO_PLUGINS]
#         )
#

include(ArtMake)
include(CetParseArgs)

function ( mrb_make )

  set(lib_option_names LIB_LIBRARIES 
                       DICT_LIBRARIES
                       MODULE_LIBRARIES 
		       SERVICE_LIBRARIES 
		       SOURCE_LIBRARIES )
  set(arg_option_names LIBRARY_NAME
                       SUBDIRS
                       EXCLUDE )
  set(noarg_option_names WITH_STATIC_LIBRARY
                         BASENAME_ONLY
                         NO_PLUGINS )
  cet_parse_args( MRB "${arg_option_names};${lib_option_names}" "${noarg_option_names}" ${ARGN})
  ##message(STATUS "mrb_make: argument list ${ARGN}")
  
  foreach( option ${lib_option_names} )
    ##message( STATUS "mrb_make: MRB_${option} ${MRB_${option}}")
    if ( MRB_${option} )
      message( STATUS "mrb_make: checking MRB_${option}")
      foreach (lib ${MRB_${option}})
	string(REGEX MATCH [/] has_path "${lib}")
	if( has_path )
          list(APPEND ${option}_list ${lib})   
	else()
          message(STATUS "check ${lib}" )
	  string(TOUPPER  ${lib} ${lib}_UC )
          if( ${${lib}_UC} )
            list(APPEND ${option}_list ${${lib}_UC})   
	  else()
            list(APPEND ${option}_list ${lib})   
	  endif()
	endif( has_path ) 
      endforeach()
    endif ( MRB_${option} )
    ##message( STATUS "mrb_make: ${option}_list ${${option}_list}")
  endforeach()
  
  # now construct the complete argument list
  foreach( option ${noarg_option_names} )
    if ( MRB_${option} )
       list(APPEND art_make_arg ${option})
    endif ( MRB_${option} )
  endforeach()
  foreach( option ${arg_option_names} )
    if ( MRB_${option} )
       list(APPEND art_make_arg ${option} "${MRB_${option}}")
    endif ( MRB_${option} )
  endforeach()
  foreach( option ${lib_option_names} )
    if ( MRB_${option} )
       list(APPEND art_make_arg ${option} "${${option}_list}")
    endif ( MRB_${option} )
  endforeach()
  ##message( STATUS "mrb_make: art_make_arg ${art_make_arg}")

  art_make( "${art_make_arg}" )

endfunction ( mrb_make )
