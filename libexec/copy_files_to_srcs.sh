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
Usage: $fullCom [-c] <MRB_SOURCE>
  This is a utility function used by newDev and updateDepsCM.
EOF
}

if [ "$1" = "-c" ]; then
  (( clean = 1 ))
  shift
fi

MRB_SOURCE=${1}

if [ -z ${MRB_SOURCE} ]
then
  echo "ERROR in copy_files_to_srcs.sh: MRB_SOURCE is not defined."
  exit 1
fi

if [ -z ${MRB_DIR} ]
then
  echo "ERROR in copy_files_to_srcs.sh: MRB_DIR is not defined."
  echo "      Note that MRB_DIR is defined when you setup mrb"
  exit 1
fi

cmake_subdir_fragment=${MRB_SOURCE}/.cmake_add_subdir
cmake_include_fragment=${MRB_SOURCE}/.cmake_include_dirs

# Construct a new CMakeLists.txt file in srcs
mrb_dot_version=${MRB_VERSION#v}
mrb_dot_version=${mrb_dot_version//_/.}
sed -Ee 's&\@mrb_project\@&'"$MRB_PROJECT"'_MRB&' \
  -e 's&\@mrb_dot_version\@&'"$mrb_dot_version"'&' \
  $mrb_templates/CMakeLists.txt.main > ${MRB_SOURCE}/CMakeLists.txt || exit

if (( clean )); then # Clear subdirectories.
  if [ -e ${cmake_subdir_fragment} ]; then rm -f ${cmake_subdir_fragment}; fi
  if [ -e ${cmake_include_fragment} ]; then rm -f ${cmake_include_fragment}; fi
  echo "# DO NOT DELETE " > ${cmake_include_fragment}
  echo "# DO NOT DELETE " > ${cmake_subdir_fragment}
fi

exit 0
