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

# Make sure we're in a build area (something called .../buildbla)
cd ${MRB_BUILDDIR}
if pwd | egrep -q '/build[^/]*$';
  then
    echo 'Removing everything in ${MRB_BUILDDIR}'
    rm -rf *
    echo 'You must now run the following:'
    echo '    source mrb setEnv <OPTIONS>'

  else
    echo 'You are not in a build directory!!'
    exit 2
fi
