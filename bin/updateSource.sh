#!/usr/bin/env bash

# run git pull on everything in $MRB_SOURCE

# No arguments


# Determine the name of this command
thisComFull=$(basename $0)
thisCom=${thisComFull%.*}
fullCom="${mrb_command} $thisCom"

# Function to show command usage
function usage() {
  cat 1>&2 << EOF
Usage: $fullCom
  update all repositories in $MRB_SOURCE
  This script will check for svn or git and use the issue the appropriate command
EOF
}

# Determine command options (just -h for help)
while getopts ":h:" OPTION
do
    case $OPTION in
        h   ) usage ; exit 0 ;;
        *   ) echo "ERROR: Unknown option" ; usage ; exit 1 ;;
    esac
done

# Some sanity checks -
if [ -z "${MRB_SOURCE}" ]
then
    echo 'ERROR: MRB_SOURCE must be defined'
    echo '       source the appropriate localProductsXXX/setup'
    exit 1
fi

if [ ! -r $MRB_SOURCE/CMakeLists.txt ]; then
    echo "$MRB_SOURCE/CMakeLists.txt not found"
    exit 1
fi

# find the directories
# ignore any directory that does not contain ups/product_deps
list=$(ls -d $MRB_SOURCE/*/)
for file in $list
do
  if [ -r ${file}ups/product_deps ]
  then
    pkglist="$(basename $file) $pkglist"
  fi
done

echo ""
echo "$thisCom: update these packages:"
echo "        $pkglist"
echo ""

for REP in $pkglist
do
   cd ${MRB_SOURCE}/${REP}
   if [ -d .svn ]
   then 
     echo "updating ${REP}"
     svn update || exit 1
   elif [ -d .git ]
   then
     echo "updating ${REP}"
     git fetch || exit 1
     git merge || exit 1
   else
      echo "ignoring ${REP} - neither git nor svn"
   fi 
done

exit 0
