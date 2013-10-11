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

# Construct the @git clone@ command
gitCommand="git clone ssh://p-$REP@cdcvs.fnal.gov/cvs/projects/$REP"

echo "NOTICE: Running $gitCommand"

# Run the @git clone@ command
$gitCommand

# Did it work?
if [ $? -ne 0 ];
then
    echo 'ERROR: The git command failed!'
    exit 1
fi

# Add this product to the CMakeLists.txt file in srcs
if grep -q \($REP\) CMakeLists.txt
  then
    echo "NOTICE: project is already in CMakeLists.txt file"
  else
    echo "ADD_SUBDIRECTORY($REP)" >> CMakeLists.txt
    echo "NOTICE: Added $REP to CMakeLists.txt file"
fi

# Turn on git flow (we will be left with the @develop@ branch selected)
cd $REP
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
echo "NOTICE: You can now 'cd $REP'"

echo " "
echo "You are now on the develop branch (check with 'git branch')"
echo "To make a new feature, do 'git flow feature start <featureName>'"
