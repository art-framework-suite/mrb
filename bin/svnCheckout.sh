#!/usr/bin/env bash

# Clone a svn repository

# Determine this command name
thisComFull=$(basename $0)
thisCom=${thisComFull%.*}
fullCom="${mrb_command} $thisCom"

# Usage function
function usage() {
    echo "Usage: $fullCom [-d destination_name] <svnRepositoryName> [version]"
    echo "   Checkout a svn Repository to your development area. You should be in the srcs directory"
    echo "   If the version is not specified, you will be on the head"
    echo "   If you provide a full path, version is ignored"

}

run_svn_command() {
    echo "NOTICE: Running $svnCommand"
    # Run the svn co command
    cd ${MRB_SOURCE}
    $svnCommand

    # Did it work?
    if [ $? -ne 0 ];
    then
	echo 'ERROR: The svn command failed!'
	exit 1
    fi
}

# Determine command options (just -h for help)
while getopts ":hd:" OPTION
do
    case $OPTION in
        h   ) usage ; exit 0 ;;
        d   ) echo "NOTICE: svn checkout will use  $OPTARG" ; destinationDir=$OPTARG ;;
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

# Construct the svn checkout command
if [ "${REP}" = "nutools" ]
then
    svnCommand="svn co  svn+ssh://p-nusoftart@cdcvs.fnal.gov/cvs/projects/nusoftsvn/$VER/nutools ${destinationDir}"
    run_svn_command
elif [ "${have_path}" = "true" ]
then
    svnCommand="svn co ${REP} ${destinationDir}"
    run_svn_command
else
    if [ -z " ${destinationDir}" ]
    then
       svnCommand="svn co http://cdcvs.fnal.gov/subversion/$REP/$VER $REP "
    else
       svnCommand="svn co http://cdcvs.fnal.gov/subversion/$REP/$VER  ${destinationDir}"
    fi
    run_svn_command
fi

# Add this product to the CMakeLists.txt file in srcs
if grep -q \($repbase\) ${MRB_SOURCE}/CMakeLists.txt
  then
    echo "NOTICE: project is already in CMakeLists.txt file"
  else
    ${MRB_DIR}/bin/add_to_cmake.sh ${MRB_SOURCE} ${repbase} || exit 1;
fi

echo " "
echo "You are now on the head"
