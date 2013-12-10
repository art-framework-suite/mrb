#!/usr/bin/env bash

# tag a git repository using git flow

# Determine this command name
thisComFull=$(basename $0)
thisCom=${thisComFull%.*}
fullCom="${mrb_command} $thisCom"

# Usage function
function usage() {
    echo "Usage: $fullCom <start|finish> <tag>"
    echo "   Call git flow start release <tag> on all packages in srcs"
    echo "     or git flow finish release <tag> on all packages in srcs"
    echo "   Be sure to edit and commit before calling finish"
    echo
    echo "work flow:"
    echo "mrb tag start <tag>"
    echo "edit ups/product_deps"
    echo "git commit ups/product_deps"
    echo "mrb tag finish <tag>"
    echo "git push origin develop master"
    echo "git push --tags"
    echo

}

# Determine command options (just -h for help)
while getopts ":h" OPTION
do
    case $OPTION in
        h   ) usage ; exit 0 ;;
        *   ) echo "ERROR: Unknown option" ; usage ; exit 1 ;;
    esac
done

# Capture the tag
flow=$1
tag=$2
if [ -z "${flow}" ]
then
    echo 'ERROR: no options specified'
    usage
    exit 1
fi
if [ -z "${tag}" ]
then
    echo 'ERROR: no tag specified'
    usage
    exit 1
fi

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
list=`ls $MRB_SOURCE -1`
for file in $list
do
   if [ -d $file ]
   then
     if [ -r $file/ups/product_deps ]
     then
       pkglist="$file $pkglist"
     fi
   fi
done

for REP in $pkglist
do
   cd ${MRB_SOURCE}/${REP}
   if [ "${flow}" = "start" ]
   then
      git flow feature start ${tag}
      okflow=$?
      if [ ! ${okflow} ]
      then
         echo "${REP} git flow failure: ${okflow}"
	 exit 1
      fi
   elif  [ "${flow}" = "finish" ]
   then
      git flow feature finish ${tag}
      okflow=$?
      if [ ! ${okflow} ]
      then
         echo "${REP} git flow failure: ${okflow}"
	 exit 1
      fi
   else
    echo 'ERROR: unrecognized command'
    usage
    exit 1
   fi
done

exit 0
