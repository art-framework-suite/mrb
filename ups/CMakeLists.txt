# this is cumbersome because we aren't using cetbuildtools

include(CMakePackageConfigHelpers)

execute_process( COMMAND date
                 OUTPUT_VARIABLE datime
                 OUTPUT_STRIP_TRAILING_WHITESPACE )

CONFIGURE_FILE ( ${CMAKE_CURRENT_SOURCE_DIR}/${product}.table.in
                 ${CMAKE_CURRENT_BINARY_DIR}/${product}.table @ONLY )
CONFIGURE_FILE ( ${CMAKE_CURRENT_SOURCE_DIR}/${product}.version.in
                 ${CMAKE_CURRENT_BINARY_DIR}/${UPSFLAVOR}_ @ONLY )
CONFIGURE_FILE ( ${CMAKE_CURRENT_SOURCE_DIR}/${product}.current.in
                 ${CMAKE_CURRENT_BINARY_DIR}/../${UPSFLAVOR}_ @ONLY )

INSTALL (FILES ${CMAKE_CURRENT_BINARY_DIR}/${product}.table
         DESTINATION ${product}/${version}/ups)
INSTALL (FILES ${CMAKE_CURRENT_BINARY_DIR}/${UPSFLAVOR}_
         DESTINATION ${product}/${version}.version/ )
INSTALL (FILES ${CMAKE_CURRENT_BINARY_DIR}/../${UPSFLAVOR}_
         DESTINATION ${product}/current.chain/ )

set( distdir ${product}/${version}/cmake )
configure_package_config_file( 
           ${CMAKE_CURRENT_SOURCE_DIR}/product-config.cmake.in
           ${CMAKE_CURRENT_BINARY_DIR}/${product}-config.cmake 
	   INSTALL_DESTINATION ${distdir} )

# allowed COMPATIBILITY values are:
# AnyNewerVersion ExactVersion SameMajorVersion
write_basic_package_version_file(
           ${CMAKE_CURRENT_BINARY_DIR}/${product}-config-version.cmake
	   VERSION ${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}
	   COMPATIBILITY AnyNewerVersion )

install( FILES ${CMAKE_CURRENT_BINARY_DIR}/${product}-config.cmake
               ${CMAKE_CURRENT_BINARY_DIR}/${product}-config-version.cmake
         DESTINATION ${distdir} )
