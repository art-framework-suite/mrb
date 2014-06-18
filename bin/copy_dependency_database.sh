#!/usr/bin/env bash

# copy base_dependency_database
# first  look in ${MRB_SOURCE}/${MRB_PROJECT}
# then look in ${MRB_PROJECTUC}_DIR 

# Determine the name of this command
thisComFull=$(basename $0)
thisCom=${thisComFull%.*}

# Merge it with the "umbrella" command (like mrb)
fullCom="${mrb_command} $thisCom"

# Function to show command usage
function usage() 
{
  cat 1>&2 << EOF
Usage: $fullCom <MRB_INSTALL> <project_directory_name>
  This is a utility function used by mrb.
EOF
}

MRB_SOURCE="${1}"
MRB_INSTALL="${2}"
prj_dir=$(printenv | grep ${3} | cut -f2 -d"=")
if [ -z ${prj_dir} ]; then prj_dir=${3}; fi

if [ -z ${MRB_SOURCE} ]
then
  echo "ERROR in copy_dependency_database.sh: MRB_SOURCE is not defined."
  exit 1
fi

if [ -z ${MRB_INSTALL} ]
then
  echo "ERROR in copy_dependency_database.sh: MRB_INSTALL is not defined."
  exit 1
fi

if [ -e ${MRB_SOURCE}/${MRB_PROJECT}/releaseDB/base_dependency_database ]
then
    echo "INFO: copying \$MRB_SOURCE/${MRB_PROJECT}/releaseDB/base_dependency_database"
    cp -p ${MRB_SOURCE}/${MRB_PROJECT}/releaseDB/base_dependency_database ${MRB_INSTALL}/.base_dependency_database
elif [ -e ${MRB_SOURCE}/${MRB_PROJECT}code/releaseDB/base_dependency_database ]
then
    echo "INFO: copying \$MRB_SOURCE/${MRB_PROJECT}code/releaseDB/base_dependency_database"
    cp -p ${MRB_SOURCE}/${MRB_PROJECT}code/releaseDB/base_dependency_database ${MRB_INSTALL}/.base_dependency_database
elif [ -e ${prj_dir}/releaseDB/base_dependency_database ]
then
    echo "INFO: copying ${prj_dir}/releaseDB/base_dependency_database"
    cp -p ${prj_dir}/releaseDB/base_dependency_database ${MRB_INSTALL}/.base_dependency_database
else 
    if [ "${3}" != "dummy" ]
    then
        echo "INFO: cannot find releaseDB/base_dependency_database"
        echo "      mrb checkDeps and pullDeps may not have complete information"
    fi
fi

exit 0

