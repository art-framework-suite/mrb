#!/usr/bin/env bash

# Delete everything in the build area

# Figure out this command name
thisComFull=$(basename $0)
thisCom=${thisComFull%.*}
fullCom="${mrb_command} $thisCom"

# Usage function
function usage() {
    echo "Usage: $fullCom"
    echo "Delete everything in both your build area and your localProducts area"
}

# Handle options
while getopts ":h" OPTION
do
    case $OPTION in
        h   ) usage ; exit 0 ;;
        *   ) echo "ERROR: Unknown option" ; usage ; exit 1 ;;
    esac
done

${MRB_DIR}/bin/zapInstall.sh
${MRB_DIR}/bin/zapBuild.sh
