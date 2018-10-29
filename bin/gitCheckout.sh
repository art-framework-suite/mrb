#!/usr/bin/env bash

# Clone a git repository

# Determine this command name
thisComFull=$(basename $0)
thisCom=${thisComFull%.*}
fullCom="${mrb_command} $thisCom"

# map special cases using associative arrays
declare -A gitToDest
declare -A destToGit
declare -A sshNameList
gitToDest=( ["artdaq-core"]="artdaq_core" \
            ["lariat-online-lariatfragments"]="lariatfragments" \
	    ["lardbt-lariatutil"]="lariatutil" \
	    ["fhicl-cpp"]="fhiclcpp" \
	    ["lbne-raw-data"]="lbne_raw_data" \
	    ["artdaq-core-demo"]="artdaq_core_demo" \
	    ["artdaq-demo"]="artdaq_demo" \
	    ["artdaq-utilities"]="artdaq_utilities" \
	    ["artdaq-utilities-ganglia-plugin"]="artdaq_ganglia_plugin" \
	    ["artdaq-utilities-epics-plugin"]="artdaq_epics_plugin" \
	    ["artdaq-utilities-database"]="artdaq_database" \
	    ["artdaq-utilities-daqinterface"]="artdaq_daqinterface" \
	    ["artdaq-utilities-mpich-plugin"]="artdaq_mpich_plugin" \
	    ["mf-extensions-git"]="artdaq_mfextensions" )
destToGit=( ["artdaq_core"]="artdaq-core" \
            ["lariatfragments"]="lariat-online-lariatfragments" \
	    ["lariatutil"]="lardbt-lariatutil" \
	    ["fhiclcpp"]="fhicl-cpp" \
	    ["lbne_raw_data"]="lbne-raw-data" \
	    ["artdaq_core_demo"]="artdaq-core-demo" \
	    ["artdaq_demo"]="artdaq-demo" \
	    ["artdaq_utilities"]="artdaq-utilities" \
	    ["artdaq_ganglia_plugin"]="artdaq-utilities-ganglia-plugin" \
	    ["artdaq_epics_plugin"]="artdaq-utilities-epics-plugin" \
	    ["artdaq_database"]="artdaq-utilities-database" \
	    ["artdaq_daqinterface"]="artdaq-utilities-daqinterface" \
	    ["artdaq_mpich_plugin"]="artdaq-utilities-mpich-plugin" \
	    ["artdaq_mfextensions"]="mf-extensions-git" )
sshNameList=( ["artdaq_core"]="artdaq" \
              ["lariatfragments"]="lariat-online" \
	      ["lariatutil"]="lardbt" \
	      ["fhiclcpp"]="fhicl-cpp" \
	      ["artdaq_ganglia_plugin"]="artdaq-utilities" \
	      ["artdaq_epics_plugin"]="artdaq-utilities" \
	      ["artdaq_database"]="artdaq-utilities" \
	      ["artdaq_daqinterface"]="artdaq-utilities" \
	      ["artdaq_mpich_plugin"]="artdaq-utilities" \
	      ["artdaq_mfextensions"]="artdaq" )

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

  Available suites:
     art_suite: 
       "cetlib_except cetlib fhiclcpp messagefacility canvas canvas_root_io art gallery critic"
     gallery_suite: 
       "cetlib_except cetlib fhiclcpp messagefacility canvas canvas_root_io gallery"
     larsoft_suite: 
       "larcore lardata larevt larsim larg4 larreco larana larexamples lareventdisplay larpandora larwirecell larsoft"
     larsoftobj_suite: 
       "larcoreobj lardataobj larcorealg lardataalg larsoftobj"
     uboone_suite:
       "uboonecode ubutil uboonedata ublite ubana ubreco ubsim ubevt ubraw ubcrt ubcore ubcv ubobj"
   

EOF
}

function short_usage() {
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
    if [ -z ${sshName} ]; then
        rbase=${1}
    else
        rbase=${sshName}
    fi
    #echo "DEBUG: run_git_command RW $gitCommand"
    #echo "DEBUG: run_git_command RO $gitCommandRO"
    #echo "DEBUG: run_git_command: ${1} sshName ${sshName}"
    #echo "DEBUG: run_git_command: rbase ${rbase}"
    #echo "DEBUG: run_git_command: REP ${REP}"
    #echo "DEBUG: run_git_command: myrep ${myrep}"
    if [ "${useRO}" == "true" ]
    then
        myGitCommand="$gitCommandRO"
    else
	myGitCommand="$gitCommand"
	if [ "$gitCommandRO" != "none" ]
	then
	    larret=`ssh p-${rbase}@cdcvs.fnal.gov "echo Hi" 2>&1`
	    is_bad=`echo $larret | egrep "Permission|authentication" | grep -v "fake authentication" | wc -l`
	    if [ $is_bad -gt 0 ]
	    then
              echo ""
              echo "NOTICE: You do not have read-write permissions for this repository"
	      myGitCommand="$gitCommandRO"
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

    # check ups/product_deps
    #echo "DEBUG: run_git_command: myrep ${myrep}"
    #echo "DEBUG: run_git_command: myDestination ${myDestination}"
    if [ -z ${myDestination} ]; then
        parent=`grep ^parent ${myrep}/ups/product_deps | awk '{print $2}'`
	repodir=${myrep}
    else
        parent=`grep ^parent ${myDestination}/ups/product_deps | awk '{print $2}'`
	repodir=${myDestination}
    fi
    if [[ ${repodir} != ${parent} ]]; then
        echo
        echo "ERROR: Product name ${parent} is inconsistent with checked out directory ${repodir}"
	echo "       Please use the following instructions to correct the problem:"
	echo "            rm -rf ${repodir}"
	echo "            mrb uc"
	echo "            run mrb g with the appropriate flags"
	echo "            for instance, mrb g -d ${parent} ..."
	echo
	short_usage
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
    #echo "DEBUG clone_init_cmake: codebase $codebase coderep $coderep"
    echo "git clone: clone $coderep at ${MRB_SOURCE}"
    cd ${MRB_SOURCE}
    run_git_command $codebase
    git_flow_init $coderep
    # change to the requested branch or tag
    if [ "x${useTag}" != "x" ]
    then
       cd ${MRB_SOURCE}/$coderep
       git checkout ${useTag}
       tagstatus=$?
       if [[ ${tagstatus} != 0 ]]; then
         echo
         echo "ERROR: git checkout of $coderep ${useTag} failed"
         echo
         exit 1
       fi
       #git branch
    fi
    if [ "x${useBranch}" != "x" ]
    then
       cd ${MRB_SOURCE}/$coderep
       git checkout ${useBranch}
       brstatus=$?
       if [[ ${brstatus} != 0 ]]; then
         echo
         echo "WARNING: git checkout of $coderep ${useBranch} failed"
         echo
         git branch
         echo
       fi
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

process_name() {
    myrep=${1}
    #echo "DEBUG: start process_name for ${myrep}"
    if [ "${have_path}" == "true" ]; then
        # If a full path is specified, then we don't need much else
        #echo "DEBUG: ${myrep} includes a path"
	if [ "${useRO}" == "true" ]; then
	   echo "ERROR: you cannot use -r when a full path is supplied"
	   exit 1
	fi
        if [ "x${destinationDir}" != "x" ]; then
	    myDestination=${destinationDir}
	else
	    myDestination=${repbase}
	fi
	gitCommand="git clone ${myrep} ${destinationDir}"
	gitCommandRO="none"
	clone_init_cmake ${repbase} ${destinationDir}
    elif [[ ${gitToDest[${myrep}]} ]]; then
        #echo "DEBUG: found gitToDest ${gitToDest[${myrep}]} for ${myrep}"
	if [ -z ${destinationDir} ]; then
            myDestination=${gitToDest[${myrep}]}
	else
	    myDestination=${destinationDir}
	fi
	if [[ ${sshNameList[${myDestination}]} ]]; then
            sshName=${sshNameList[${myDestination}]}
	else
            sshName=${myrep}
	fi
	gitCommand="git clone ssh://p-${sshName}@cdcvs.fnal.gov/cvs/projects/${myrep} ${myDestination}"
	gitCommandRO="git clone http://cdcvs.fnal.gov/projects/${myrep} ${myDestination}"
	clone_init_cmake ${repbase} ${myDestination}
    elif [[ ${destToGit[${myrep}]} ]]; then
        #echo "DEBUG: found destToGit ${destToGit[${myrep}]} for ${myrep}"
	if [ -z ${destinationDir} ]; then
	    myDestination=${myrep} 
	else
	    myDestination=${destinationDir}
	fi
	myrep=${destToGit[${myrep}]}
	if [[ ${sshNameList[${myDestination}]} ]]; then
            sshName=${sshNameList[${myDestination}]}
	else
            sshName=${myrep}
	fi
	gitCommand="git clone ssh://p-${sshName}@cdcvs.fnal.gov/cvs/projects/${myrep} ${myDestination}"
	gitCommandRO="git clone http://cdcvs.fnal.gov/projects/${myrep} ${myDestination}"
	clone_init_cmake ${repbase} ${myDestination}
    else
        #echo "DEBUG: plain jane checkout for ${myrep}"
        sshName=${myrep}
	if [ -z ${destinationDir} ]; then
	    myDestination=${myrep} 
	else
	    myDestination=${destinationDir}
	fi
	gitCommand="git clone ssh://p-${myrep}@cdcvs.fnal.gov/cvs/projects/${myrep} ${myDestination}"
	gitCommandRO="git clone http://cdcvs.fnal.gov/projects/${myrep} ${myDestination}"
	clone_init_cmake ${myrep} ${myDestination}
    fi
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
larsoft_list="larcore lardata larevt larsim larg4 larreco larana larexamples lareventdisplay larpandora larwirecell larsoft"
art_list="cetlib_except cetlib fhiclcpp messagefacility canvas canvas_root_io art gallery critic"
critic_list="cetlib_except cetlib fhiclcpp messagefacility canvas canvas_root_io art gallery critic"
gallery_list="cetlib_except cetlib fhiclcpp messagefacility canvas canvas_root_io gallery"
larsoftobj_list="larcoreobj lardataobj larcorealg lardataalg larsoftobj"
uboone_list="uboonecode ubutil uboonedata ublite ubana ubreco ubsim ubevt ubraw ubcrt ubcore ubcv ubobj"

if [ "${REP}" = "larsoft_suite" ]
then
    if [ "x${useTag}" != "x" ]
    then
       already_set=`echo ${useTag} | grep LARSOFT_SUITE | wc -l`
       if [ $already_set -eq 0 ]
       then
	 useTag=LARSOFT_SUITE_${useTag}
	 echo "INFO: git clone will use tag ${useTag} for the larsoft suite"
       fi
    fi
    for code in ${larsoft_list}
    do
        process_name $code
    done
elif [ "${REP}" = "art_suite" ]
then
    if [ "x${useTag}" != "x" ]
    then
       already_set=`echo ${useTag} | grep ART_SUITE | wc -l`
       if [ $already_set -eq 0 ]
       then
	 useTag=ART_SUITE_${useTag}
	 echo "INFO: git clone will use tag ${useTag} for the art suite"
       fi
    fi
    for code in ${art_list}
    do
        #echo "DEBUG: begin $code"
        process_name $code
    done
elif [ "${REP}" = "critic_suite" ]
then
    if [ "x${useTag}" != "x" ]
    then
       already_set=`echo ${useTag} | grep ART_SUITE | wc -l`
       if [ $already_set -eq 0 ]
       then
	 useTag=ART_SUITE_${useTag}
	 echo "INFO: git clone will use tag ${useTag} for the critic suite"
       fi
    fi
    for code in ${critic_list}
    do
        process_name $code
    done
elif [ "${REP}" = "gallery_suite" ]
then
    if [ "x${useTag}" != "x" ]
    then
       already_set=`echo ${useTag} | grep GALLERY_SUITE | wc -l`
       if [ $already_set -eq 0 ]
       then
	 useTag=GALLERY_SUITE_${useTag}
	 echo "INFO: git clone will use tag ${useTag} for the gallery suite"
       fi
    fi
    for code in ${gallery_list}
    do
        process_name $code
    done
elif [ "${REP}" = "larsoftobj_suite" ]
then
    if [ "x${useTag}" != "x" ]
    then
       already_set=`echo ${useTag} | grep LARSOFTOBJ | wc -l`
       if [ $already_set -eq 0 ]
       then
	 useTag=LARSOFTOBJ_${useTag}
	 echo "INFO: git clone will use tag ${useTag} for the gallery suite"
       fi
    fi
    for code in ${larsoftobj_list}
    do
        process_name $code
    done
elif [ "${REP}" = "uboone_suite" ]
then
    if [ "x${useTag}" != "x" ]
    then
       already_set=`echo ${useTag} | grep UBOONE_SUITE | wc -l`
       if [ $already_set -eq 0 ]
       then
	 useTag=UBOONE_SUITE_${useTag}
	 echo "INFO: git clone will use tag ${useTag} for the larsoft suite"
       fi
    fi
    for code in ${uboone_list}
    do
        process_name $code
    done
else
    process_name ${REP}
fi

echo " "

if [[ ${useTag} ]]; then
    echo "You are now on ${useTag}"
elif [[ ${useBranch} ]]; then
    echo "You are now on ${useBranch}"
else
    echo "You are now on the develop branch (check with 'git branch')"
    echo "To make a new feature, do 'git flow feature start <featureName>'"
fi
