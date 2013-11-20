#!/usr/bin/env bash

# Clone a svn repository

# Determine this command name
thisComFull=$(basename $0)
thisCom=${thisComFull%.*}
fullCom="${mrb_command} $thisCom"

# Usage function
function usage() {
    echo "Usage: $fullCom <svnRepositoryName> [version]"
    echo "   Checkout a svn Repository to your development area. You should be in the srcs directory"
    echo "   If the version is not specified, you will be on the head"

}

run_svn_command() {
    echo "NOTICE: Running $svnCommand"
    # Run the svn co command
    $svnCommand

    # Did it work?
    if [ $? -ne 0 ];
    then
	echo 'ERROR: The svn command failed!'
	exit 1
    fi
}

add_to_cmake() {
    myrep=$1
    cd ${MRB_SOURCE}
    cp ${MRB_DIR}/templates/CMakeLists.txt.master CMakeLists.txt || exit 1;
    # have to accumulate the include_directories command in one fragment
    # and the add_subdirectory commands in another fragment
    pkgname=`grep parent ${MRB_SOURCE}/${myrep}/ups/product_deps  | grep -v \# | awk '{ printf $2; }'`
    echo "# ${myrep} package block" >> cmake_include_dirs
    echo "set(${pkgname}_not_in_ups true)" >> cmake_include_dirs
    echo "include_directories ( \${CMAKE_CURRENT_SOURCE_DIR}/${myrep} )" >> cmake_include_dirs
    cat cmake_include_dirs >> CMakeLists.txt
    echo ""  >> CMakeLists.txt
    echo "ADD_SUBDIRECTORY($myrep)" >> cmake_add_subdir
    cat cmake_add_subdir >> CMakeLists.txt
    echo ""  >> CMakeLists.txt
    echo "NOTICE: Added $myrep to CMakeLists.txt file"
}

# Determine command options (just -h for help)
while getopts ":h" OPTION
do
    case $OPTION in
        h   ) usage ; exit 0 ;;
        *   ) echo "ERROR: Unknown option" ; usage ; exit 1 ;;
    esac
done

# Did the user provide a product name?
shift $((OPTIND - 1))
if [ $# -lt 1 ]; then
    echo "ERROR: No SVN Repository Given"
    usage
    exit 1
fi

# Capture the product name
REP=$1

# check for version
if [ $# -lt 2 ]; then
    echo "NOTICE: No version specified, using the head"
    VER="trunk"
else
    VER=tags/$2
fi

# Ensure that the current directory is @srcs/@
if echo $PWD | egrep -q "/srcs$";
then
    ok=1
else
    echo 'ERROR: You must be in your srcs directory'
    exit 1
fi

# Make sure this product isn't already checked out
if ls -1 | egrep -q ^${REP}$;
then
    echo "ERROR: $REP directory already exists!"
    exit 1
fi

# Construct the svn checkout command


if [ "${REP}" = "nutools" ]
then
    svnCommand="svn co  svn+ssh://p-nusoftart@cdcvs.fnal.gov/cvs/projects/nusoftsvn/$VER/nutools"
    run_svn_command
else
    svnCommand="svn co http://cdcvs.fnal.gov/subversion/$REP/$VER $REP"
    run_svn_command
fi

# Add this product to the CMakeLists.txt file in srcs
if grep -q \($REP\) ${MRB_SOURCE}/CMakeLists.txt
  then
    echo "NOTICE: project is already in CMakeLists.txt file"
  else
    add_to_cmake $REP
fi

echo " "
echo "You are now on the head"
