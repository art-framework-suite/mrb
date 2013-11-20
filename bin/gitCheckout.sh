#!/usr/bin/env bash

# Clone a git repository

# Determine this command name
thisComFull=$(basename $0)
thisCom=${thisComFull%.*}
fullCom="${mrb_command} $thisCom"

# Usage function
function usage() {
    echo "Usage: $fullCom <gitRepositoryName>"
    echo "   Clone a Git Repository to your development area. You should be in the srcs directory"

}

run_git_command() {
    echo "NOTICE: Running $gitCommand"
    # Run the git clone command
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
    cd $myrep
    git flow init -d > /dev/null

    # Check for a remote @develop@ branch. If there is one, track it.
    if git branch -r | grep -q origin/develop;
    then
	## Make @develop@ a tracking branch
	echo 'NOTICE: Making develop a tracking branch of origin/develop'
	git checkout master
	git branch -d develop
	git branch --track develop origin/develop
	git checkout develop
    fi

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
if [ $# -ne 1 ]; then
    echo "ERROR: No Git Repository Given"
    usage
    exit 1
fi

# Capture the product name
REP=$1

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

# Construct the git clone command
larsoft_list="larcore  lardata larevt larsim larreco larana larexamples lareventdisplay"
if [ "${REP}" = "larsoft" ]
then
    gitCommand="git clone ssh://p-$REP-alpha@cdcvs.fnal.gov/cvs/projects/$REP-alpha $REP"
    run_git_command
elif [ "${REP}" = "larsoft_suite" ]
then
    for code in ${larsoft_list}
    do
        gitCommand="git clone ssh://p-$code@cdcvs.fnal.gov/cvs/projects/$code"
	run_git_command
    done
    gitCommand="git clone ssh://p-larsoft-alpha@cdcvs.fnal.gov/cvs/projects/larsoft-alpha larsoft"
    run_git_command
else
    gitCommand="git clone ssh://p-$REP@cdcvs.fnal.gov/cvs/projects/$REP"
    run_git_command
fi

# Turn on git flow (we will be left with the @develop@ branch selected)
if [ "${REP}" = "larsoft_suite" ]
then
    for code in ${larsoft_list} larsoft
    do 
       git_flow_init $code
    done
else
  git_flow_init $REP
fi

# Add this product to the CMakeLists.txt file in srcs
if [ "${REP}" = "larsoft_suite" ]
then
   echo "You must now run \"mrb updateDepsCM\""
else
   if grep -q \($REP\) ${MRB_SOURCE}/CMakeLists.txt
     then
       echo "NOTICE: project is already in CMakeLists.txt file"
     else
       add_to_cmake $REP
   fi
fi

echo " "
echo "You are now on the develop branch (check with 'git branch')"
echo "To make a new feature, do 'git flow feature start <featureName>'"
