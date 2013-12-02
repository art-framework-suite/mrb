#!/usr/bin/env bash

# Clone a git repository

# Determine this command name
thisComFull=$(basename $0)
thisCom=${thisComFull%.*}
fullCom="${mrb_command} $thisCom"

# Usage function
function usage() {
    echo "Usage: $fullCom <gitRepositoryName> [destination_name]"
    echo "   Clone a Git Repository to your development area. You should be in the srcs directory"

}

run_git_command() {
    echo "NOTICE: Running $gitCommand"
    # Run the git clone command
    cd ${MRB_SOURCE}
    $gitCommand

    # Did it work?
    if [ $? -ne 0 ];
    then
	echo 'ERROR: The git command failed!'
	exit 1
    fi
}

git_flow_init() {
    myrep=$1
    cd ${MRB_SOURCE}/$myrep
    # this is necessary for those packages where the default branch is not master
    echo "ready to run git flow init for $myrep"
    git checkout master
    git flow init -d > /dev/null

    # Display informational messages
    echo "NOTICE: You can now 'cd $myrep'"
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

clone_init_cmake() {
    if [ -z "${2}" ]
    then
      coderep=${1}
    else
      coderep=${2}
    fi
    echo "git clone: clone $coderep at ${MRB_SOURCE}"
    cd ${MRB_SOURCE}
    run_git_command
    git_flow_init $coderep
    # add to CMakeLists.txt
    if grep -q \($coderep\) ${MRB_SOURCE}/CMakeLists.txt
      then
	echo "NOTICE: project is already in CMakeLists.txt file"
      else
	add_to_cmake $coderep
    fi
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
    echo "ERROR: No Git Repository Given"
    usage
    exit 1
fi

# Capture the product name and optional destination
REP=$1
destinationDir=$2

# Ensure that the current directory is @srcs/@
if echo $PWD | egrep -q "/srcs$";
then
    ok=1
else
    echo 'ERROR: You must be in your srcs directory'
    exit 1
fi

if [ -z "${MRB_SOURCE}" ]
then
    echo 'ERROR: MRB_SOURCE must be defined'
    echo '       source the appropriate localProductsXXX/setup'
    exit 1
fi

# check to see if we have a path already
if echo ${REP} | grep -q '/';
then
  have_path=true
  repbase=`basename ${REP}`
else
  have_path=false
  repbase=${REP}
fi

# Make sure this product isn't already checked out
# You can only have one copy of a given repository in any given srcs directory
if [ -d ${MRB_SOURCE}/${repbase} ]
then
    echo "ERROR: $repbase directory already exists!"
    exit 1
fi
if [ "x${destinationDir}" != "x" ] && [ -d ${MRB_SOURCE}/${destinationDir} ]
then
    echo "ERROR: ${MRB_SOURCE}/${destinationDir} directory already exists!"
    exit 1
fi

# Construct the git clone command
# Special cases for larsoft
larsoft_list="larcore  lardata larevt larsim larreco larana larexamples lareventdisplay"
if [ "${REP}" = "larsoft" ]
then
    if [ -z " ${destinationDir}" ]
    then
       gitCommand="git clone ssh://p-$REP-alpha@cdcvs.fnal.gov/cvs/projects/$REP-alpha $REP"
    else
       gitCommand="git clone ssh://p-$REP-alpha@cdcvs.fnal.gov/cvs/projects/$REP-alpha ${destinationDir}"
    fi
    clone_init_cmake larsoft ${destinationDir}
elif [ "${REP}" = "larsoft_suite" ]
then
    for code in ${larsoft_list}
    do
        gitCommand="git clone ssh://p-$code@cdcvs.fnal.gov/cvs/projects/$code"
	clone_init_cmake $code
    done
    gitCommand="git clone ssh://p-larsoft-alpha@cdcvs.fnal.gov/cvs/projects/larsoft-alpha larsoft"
    clone_init_cmake larsoft
elif [ "${have_path}" = "true" ]
then
    gitCommand="git clone $REP ${destinationDir}"
    clone_init_cmake $repbase ${destinationDir}
else
    gitCommand="git clone ssh://p-$REP@cdcvs.fnal.gov/cvs/projects/$REP ${destinationDir}"
    clone_init_cmake $REP ${destinationDir}
fi

echo " "
echo "You are now on the develop branch (check with 'git branch')"
echo "To make a new feature, do 'git flow feature start <featureName>'"
