#!/usr/bin/env bash

# Delete everything in the install area

# Figure out this command name
thisComFull=$(basename $0)
thisCom=${thisComFull%.*}
fullCom="${mrb_command} $thisCom"

# Usage function
function usage() {
    echo "Usage: $fullCom"
    echo "Delete everything in your localProducts area"
}

# Handle options
while getopts ":h" OPTION
do
    case $OPTION in
        h   ) usage ; exit 0 ;;
        *   ) echo "ERROR: Unknown option" ; usage ; exit 1 ;;
    esac
done

# Let's make sure we are not already sitting in a localProducts area
if pwd | egrep -q '/local[^/]*$';
  then
     pwda=`pwd`
     reldir=`${MRB_DIR}/bin/findDir.sh ${pwda}`
     bdir=`${MRB_DIR}/bin/findDir.sh ${MRB_INSTALL}`
     if [ ${reldir} != ${bdir} ];
       then
         echo "ERROR: You are sitting in ${reldir}, but \$MRB_INSTALL=${MRB_INSTALL} !!"
         echo "cd to \$MRB_INSTALL or out of the build area"
         exit 3
     fi
fi

# Make sure we're in a localProducts area
cd ${MRB_INSTALL}
if pwd | egrep -q '/local[^/]*$';
  then
    echo "Removing all products from in ${MRB_INSTALL}"
    product_list=`find . -maxdepth 1 -type d`
    for pdir in ${product_list}
    do
      rm -rf ${pdir}
    done
  else
    echo "ERROR: ${MRB_INSTALL} does not point to a directory that starts with local"
    exit 2
fi
