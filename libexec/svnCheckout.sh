#!/usr/bin/env bash

# Clone a svn repository

# Determine this command name
thisComFull=$(basename $0)
thisCom=${thisComFull%.*}
fullCom="${mrb_command} $thisCom"

# Usage function
function usage() {
 cat 1>&2 << EOF
Usage: $fullCom [-r] [-d destination_name] [-b branch] [-t tag] <svnRepositoryName>
  Checkout a svn Repository to your development area. You should be in the srcs directory.
  By default, you will be on the HEAD.
  Options:

     -r                    = checkout a read-only copy
     
     -d <destination_name> = use this name instead of the default repository name
    
     -b <branch>           = checkout this branch
     
     -t <tag>              = checkout this tag

EOF
}

run_svn_command() {

    if [ "${useRO}" == "true" ]
    then
        mySvnCommand=$svnCommandRO
    else
	mySvnCommand=$svnCommand
    fi

    echo "NOTICE: Running $mySvnCommand"
    # Run the svn co command
    cd ${MRB_SOURCE}
    $mySvnCommand

    # Did it work?
    if [ $? -ne 0 ];
    then
	echo 'ERROR: The svn command failed!'
	exit 1
    fi
}

VER="trunk"

# Determine command options (just -h for help)
while getopts ":hrb:d:t:" OPTION
do
    case $OPTION in
        h   ) usage ; exit 0 ;;
        d   ) echo "NOTICE: svn checkout will use destination name $OPTARG" ; destinationDir=$OPTARG ;;
        b   ) echo "NOTICE: svn checkout will use branch $OPTARG" ; useBranch=$OPTARG ;;
        t   ) echo "NOTICE: svn checkout will use tag $OPTARG" ; useTag=$OPTARG ;;
	r   ) echo "NOTICE: svn will checkout a read-only copy"; useRO=true ;;
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
if [ "x${useTag}" != "x" ]
then
    VER=tags/${useTag}
elif [ "x${useBranch}" != "x" ]
then
    VER=branch/${useBranch}
else
    echo "NOTICE: No version specified, using the head"
    VER="trunk"
fi

if [ -z "${MRB_SOURCE}" ]
then
    echo 'ERROR: MRB_SOURCE must be defined'
    echo '       source the appropriate localProductsXXX/setup'
    exit 1
fi

# Ensure that the current directory is @srcs/@
cd ${MRB_SOURCE}
if echo $PWD | egrep -q "/srcs$";
then
    ok=1
else
    echo 'ERROR: MRB_SOURCE is improperly defined'
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

# Construct the svn checkout command
if [ "${REP}" = "nutools" ]
then
    svnCommand="svn co  svn+ssh://p-nusoftart@cdcvs.fnal.gov/cvs/projects/nusoftsvn/$VER/nutools ${destinationDir}"
    svnCommandRO="svn co  http://cdcvs.fnal.gov/subversion/nusoftsvn/$VER/nutools ${destinationDir}"
    run_svn_command
elif [ "${have_path}" = "true" ]
then
    if [ "${useRO}" == "true" ]
    then
       echo "ERROR: you cannot use -r when a full path is supplied"
       exit 1
    fi
    svnCommand="svn co ${REP} ${destinationDir}"
    run_svn_command
else
    if [ -z " ${destinationDir}" ]
    then
       svnCommand="svn co svn+ssh://p-nusoftart@cdcvs.fnal.gov/cvs/projects/$REP/$VER $REP "
       svnCommandRO="svn co http://cdcvs.fnal.gov/subversion/$REP/$VER $REP "
    else
       svnCommand="svn co svn+ssh://p-nusoftart@cdcvs.fnal.gov/cvs/projects/$REP/$VER  ${destinationDir}"
       svnCommandRO="svn co http://cdcvs.fnal.gov/subversion/$REP/$VER  ${destinationDir}"
    fi
    run_svn_command
fi

# Add this product to the CMakeLists.txt file in srcs
if grep -q \($repbase\) ${MRB_SOURCE}/CMakeLists.txt
  then
    echo "NOTICE: project is already in CMakeLists.txt file"
  else
    $MRB_DIR/libexec/add_to_cmake.sh ${MRB_SOURCE} ${repbase} || exit 1;
fi

echo " "
echo "You are now on the head"
