#!/usr/bin/env bash

# Clone a git repository

# Determine this command name
thisComFull=$(basename $0)
thisCom=${thisComFull%.*}
fullCom="${mrb_command} $thisCom"

# Usage function
function usage() {
  cat 1>&2 << EOF
Usage: $fullCom [-r] [-d destination_name] [-b branch] [-t tag] <gitRepositoryName>
  Clone a Git Repository to your development area. You should be in the srcs directory.
  By default, you will be on the HEAD.
  Options:

     -r                    = clone a read-only copy
     
     -d <destination_name> = use this name instead of the default repository name
    
     -b <branch>           = git clone, and then git checkout this branch
     
     -t <tag>              = git clone, and then git checkout this tag

EOF
}

run_git_command() {
    # First check permissions
    rbase=${1}
    if [ "${useRO}" == "true" ]
    then
        myGitCommand=$gitCommandRO
    else
	myGitCommand=$gitCommand
	if [ "$gitCommandRO" != "none" ]
	then
	    larret=`ssh p-${rbase}@cdcvs.fnal.gov "echo Hi" 2>&1`
	    is_bad=`echo $larret | grep Permission | wc -l`
	    if [ $is_bad -gt 0 ]
	    then
              echo ""
              echo "NOTICE: You do not have read-write permissions for this repository"
              echo "--->> DID YOU RUN kinit TO GET A KERBEROS TICKET? <<---"
	      myGitCommand=$gitCommandRO
	    fi
	fi
    fi
    echo "NOTICE: Running $myGitCommand"
    # Run the git clone command
    cd ${MRB_SOURCE}
    $myGitCommand

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
    # make sure we are on the develop branch
    git checkout develop
    # just in case we are using an older git flow
    git branch --set-upstream-to=origin/develop
    git pull
}

clone_init_cmake() {
    codebase=${1}
    if [ -z "${2}" ]
    then
      coderep=${1}
    else
      coderep=${2}
    fi
    echo "git clone: clone $coderep at ${MRB_SOURCE}"
    cd ${MRB_SOURCE}
    run_git_command $codebase
    git_flow_init $coderep
    # change to the requested branch or tag
    if [ "x${useTag}" != "x" ]
    then
       cd ${MRB_SOURCE}/$coderep
       git checkout ${useTag}
    fi
    if [ "x${useBranch}" != "x" ]
    then
       cd ${MRB_SOURCE}/$coderep
       git checkout ${useBranch}
    fi
    # add to CMakeLists.txt
    if grep -q \($coderep\) ${MRB_SOURCE}/CMakeLists.txt
      then
	echo "NOTICE: project is already in CMakeLists.txt file"
      else
	#add_to_cmake $coderep
	${MRB_DIR}/bin/add_to_cmake.sh ${MRB_SOURCE} ${coderep} || exit 1;
    fi

    # Display informational messages
    echo "NOTICE: You can now 'cd $myrep'"
}

# Determine command options (just -h for help)
while getopts ":hrb:d:t:" OPTION
do
    case $OPTION in
        h   ) usage ; exit 0 ;;
        d   ) echo "NOTICE: git clone will use destination name $OPTARG" ; destinationDir=$OPTARG ;;
        b   ) echo "NOTICE: git clone will use branch $OPTARG" ; useBranch=$OPTARG ;;
        t   ) echo "NOTICE: git clone will use tag $OPTARG" ; useTag=$OPTARG ;;
	r   ) echo "NOTICE: git will clone a read-only copy"; useRO=true ;;
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

# Capture the product name
REP=$1

# check for version
if [ $# -lt 2 ]; then
    VER="head"
else
    VER=$2
fi

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
larsoft_list="larcore larpandora lardata larevt larsim larreco larana larexamples lareventdisplay larsoft"
if [ "${REP}" = "larsoft_suite" ]
then
    for code in ${larsoft_list}
    do
        gitCommand="git clone ssh://p-$code@cdcvs.fnal.gov/cvs/projects/$code"
	gitCommandRO="git clone http://cdcvs.fnal.gov/projects/$code"
	clone_init_cmake $code
    done
elif [ "${have_path}" == "true" ]
then
    if [ "${useRO}" == "true" ]
    then
       echo "ERROR: you cannot use -r when a full path is supplied"
       exit 1
    fi
    gitCommand="git clone $REP ${destinationDir}"
    gitCommandRO="none"
    clone_init_cmake $repbase ${destinationDir}
else
    gitCommand="git clone ssh://p-$REP@cdcvs.fnal.gov/cvs/projects/$REP ${destinationDir}"
    gitCommandRO="git clone http://cdcvs.fnal.gov/projects/$REP ${destinationDir}"
    clone_init_cmake $REP ${destinationDir}
fi

echo " "

if [ "${VER}" != "head" ]
then
    echo "You are now on ${VER}"
else
    echo "You are now on the develop branch (check with 'git branch')"
    echo "To make a new feature, do 'git flow feature start <featureName>'"
fi
