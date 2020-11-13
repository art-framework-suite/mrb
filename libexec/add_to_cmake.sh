#!/usr/bin/env bash

# Determine the name of this command
thisComFull=$(basename $0)
thisCom=${thisComFull%.*}

# Merge it with the "umbrella" command (like mrb)
fullCom="${mrb_command} $thisCom"

# Function to show command usage
function usage() 
{
  cat 1>&2 << EOF
Usage: $fullCom <MRB_SOURCE> <repository_name>
  This is a utility function used by mrb.
EOF
}

MRB_SOURCE="${1}"
pkglist="${2}"

if [ -z ${MRB_SOURCE} ]
then
  echo "ERROR in add_to_cmake.sh: MRB_SOURCE is not defined."
  exit 1
fi

if [ -z "${pkglist}" ]
then
  echo "ERROR in add_to_cmake.sh: repository name is not defined."
  exit 1
fi

if [ -z ${MRB_DIR} ]
then
  echo "ERROR in add_to_cmake.sh: MRB_DIR is not defined."
  echo "      Note that MRB_DIR is defined when you setup mrb"
  exit 1
fi

# we might be working with a srcs directory created by an older mrb release
if [ -e ${MRB_SOURCE}/.cmake_add_subdir ]
then
   cmake_subdir_fragment=${MRB_SOURCE}/.cmake_add_subdir
   cmake_include_fragment=${MRB_SOURCE}/.cmake_include_dirs
elif [ -e ${MRB_SOURCE}/cmake_add_subdir ]
then
   cmake_subdir_fragment=${MRB_SOURCE}/cmake_add_subdir
   cmake_include_fragment=${MRB_SOURCE}/cmake_include_dirs
else
   # no fragments - make new 
   cmake_subdir_fragment=${MRB_SOURCE}/.cmake_add_subdir
   cmake_include_fragment=${MRB_SOURCE}/.cmake_include_dirs
fi

cd ${MRB_SOURCE}
$MRB_DIR/libexec/copy_files_to_srcs.sh ${MRB_SOURCE} || exit

# have to accumulate the include_directories command in one fragment
# and the add_subdirectory commands in another fragment
for REP in $pkglist
do
   # Sanity checks
   if [ ! -r $REP/CMakeLists.txt ]; then echo "Cannot find CMakeLists.txt in $REP"; break; fi
   if [ ! -r $REP/ups/product_deps ]; then echo "Cannot find ups/product_deps in $REP"; break; fi
   pkgname=`grep parent ${MRB_SOURCE}/${REP}/ups/product_deps  | grep -v \# | awk '{ printf $2; }'`
   cat >> "${cmake_include_fragment}" <<EOF
# ${REP} package block
include_directories(\${CMAKE_CURRENT_SOURCE_DIR}/${REP})
include_directories(\$ENV{MRB_BUILDDIR}/${REP})
EOF
   cat >> "${cmake_subdir_fragment}" <<EOF
add_subdirectory(${REP})
cet_process_cmp()
EOF
   echo "NOTICE: Adding ${REP} to CMakeLists.txt file"
done

cat ${cmake_include_fragment} >> ${MRB_SOURCE}/CMakeLists.txt
echo ""  >> ${MRB_SOURCE}/CMakeLists.txt || exit 1;
cat ${cmake_subdir_fragment} >> ${MRB_SOURCE}/CMakeLists.txt
echo ""  >> ${MRB_SOURCE}/CMakeLists.txt || exit 1;

exit 0


