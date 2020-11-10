#!/usr/bin/env bash

# Delete everything in the build area

# Figure out this command name
thisComFull=$(basename $0)
thisCom=${thisComFull%.*}
fullCom="${mrb_command} $thisCom"

# Usage function
function usage() {
    echo "Usage: $fullCom"
    echo "Delete everything in your build area"
}

# Handle options
while getopts ":h" OPTION
do
    case $OPTION in
        h   ) usage ; exit 0 ;;
        *   ) echo "ERROR: Unknown option" ; usage ; exit 1 ;;
    esac
done

# Let's make sure we are not already sitting in a build area
if pwd | egrep -q '/build[^/]*$';
  then
     pwda=`pwd`
     reldir=`$MRB_DIR/libexec/findDir.sh ${pwda}`
     bdir=`$MRB_DIR/libexec/findDir.sh ${MRB_BUILDDIR}`
     if [ "${reldir}" != "${bdir}" ];
       then
         echo "ERROR: You are sitting in \"${reldir}\", but \$MRB_BUILDDIR=\"${MRB_BUILDDIR}\" !!"
         echo "cd to \"\$MRB_BUILDDIR\" or out of the build area"
         exit 3
     fi
fi

# Make sure we're in a build area (something called .../buildbla)
cd ${MRB_BUILDDIR}
if pwd | egrep -q '/build[^/]*$';
  then
    echo "Removing everything in ${MRB_BUILDDIR}"
    rm -rf * .??*
    echo 'You must now run the following:'
    echo '    mrbsetenv'

  else
    echo "ERROR: ${MRB_BUILDDIR} does not point to a directory that starts with build"
    exit 2
fi
