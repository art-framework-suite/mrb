#!/usr/bin/env bash

# Update the CMakeLists.txt file with the latest versions of dependencies

# No arguments

# Determine the name of this command
thisComFull=$(basename $0)
thisCom=${thisComFull%.*}
fullCom="${mrb_command} $thisCom"

# Function to show command usage
function usage() {
  cat 1>&2 << EOF
Usage: $fullCom
  Update the CMakeLists.txt file with the latest versions of dependencies.

  Options:
     -b = Copy CMakeLists.txt to CMakeLists.txt.bak first (backup)
EOF
}

doBak=""

# Determine command options (just -h for help)
while getopts ":hbf:" OPTION
do
    case $OPTION in
        h   ) usage ; exit 0 ;;
        b   ) doBak="yes" ;;
        *   ) echo "ERROR: Unknown option" ; usage ; exit 1 ;;
    esac
done

# Some sanity checks -
if [ ! -r $MRB_SOURCE/CMakeLists.txt ]; then
    echo "$MRB_SOURCE/CMakeLists.txt not found"
    exit 1
fi

if [ -z $MRB_SOURCE ]
then
  echo "ERROR: MRB_SOURCE is undefined."
  exit 1
fi

# Backup?
if [ $doBak ]; then
  cp $MRB_SOURCE/CMakeLists.txt $MRB_SOURCE/CMakeLists.txt.bak
  cp $MRB_SOURCE/cmake_add_subdir $MRB_SOURCE/cmake_add_subdir.bak
  cp $MRB_SOURCE/cmake_include_dirs $MRB_SOURCE/cmake_include_dirs.bak
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

echo ""
echo "updateDepsCM: rewrite $MRB_SOURCE/CMakeLists.txt for these packages:"
echo "        $pkglist"
echo ""

# Construct a new CMakeLists.txt file in srcs
cp ${MRB_DIR}/templates/CMakeLists.txt.master $MRB_SOURCE/CMakeLists.txt || exit 1;
rm -f $MRB_SOURCE/cmake_add_subdir
echo "# DO NOT DELETE cmake_add_subdir" > $MRB_SOURCE/cmake_add_subdir
rm -f $MRB_SOURCE/cmake_include_dirs
echo "# DO NOT DELETE cmake_include_dirs" > $MRB_SOURCE/cmake_include_dirs

# have to accumulate the include_directories command in one fragment
# and the add_subdirectory commands in another fragment
for REP in $pkglist
do
   pkgname=`grep parent ${MRB_SOURCE}/${REP}/ups/product_deps  | grep -v \# | awk '{ printf $2; }'`
   echo "# ${REP} package block" >> $MRB_SOURCE/cmake_include_dirs
   echo "set(${pkgname}_not_in_ups true)" >> $MRB_SOURCE/cmake_include_dirs
   echo "include_directories ( \${CMAKE_CURRENT_SOURCE_DIR}/${REP} )" >> $MRB_SOURCE/cmake_include_dirs
   echo "ADD_SUBDIRECTORY(${REP})" >> $MRB_SOURCE/cmake_add_subdir
   echo "NOTICE: Adding ${REP} to CMakeLists.txt file"
done

cat $MRB_SOURCE/cmake_include_dirs >> $MRB_SOURCE/CMakeLists.txt
echo ""  >> $MRB_SOURCE/CMakeLists.txt
cat $MRB_SOURCE/cmake_add_subdir >> $MRB_SOURCE/CMakeLists.txt
echo ""  >> $MRB_SOURCE/CMakeLists.txt

exit 0
