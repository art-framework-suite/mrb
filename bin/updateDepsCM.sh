#!/usr/bin/env bash

# Update the CMakeLists.txt file with the latest versions of dependencies

# No arguments

# Determine the name of this command
thisComFull=$(basename $0)
thisCom=${thisComFull%.*}

# Merge it with the "umbrella" command (like gm2d)
fullCom="$umbCom $thisCom"

# Function to show command usage
function usage() {
  cat 1>&2 << EOF
Usage: $fullCom
  Update the CMakeLists.txt file with the latest versions of dependencies.

  Options:
     -b = Copy CMakeLists.txt to CMakeLists.txt.bak first (backup)
     -f = Specify the file (default is CMakeLists.txt)
EOF
}

# Choose the file
f="CMakeLists.txt"
doBak=""

# Determine command options (just -h for help)
while getopts ":hbf:" OPTION
do
    case $OPTION in
        h   ) usage ; exit 0 ;;
        b   ) doBak="yes" ;;
        f   ) f=$OPTARG ;;
        *   ) echo "ERROR: Unknown option" ; usage ; exit 1 ;;
    esac
done

# Some sanity checks -
if [ ! -r $f ]; then
    echo "$f not found"
    exit 1
fi

# Backup?
if [ $doBak ]; then
  cp $f ${f}.bak
fi

python $thisDirA/update_deps_cmakeliststxt.py $f

exit 0
