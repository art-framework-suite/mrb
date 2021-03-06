#!/usr/bin/env bash

# Set up a new development area.
# * Create a srcs directory for source code
# * Create a top build area
# * Create a local products area
# * Construct a @setup@ script in local products

# Within the srcs area is a top level @CMakeLists.txt@ file so that
# you can build everything in @srcs@.

# The local products area directory name has the version and qualifier of @${MRB_PROJECT}@
# that you currently have set up. It also makes a setup script in there that is necessary
# to source when using mrb. 

# Determine the name of this command
thisComFull=$(basename $0)
thisCom=${thisComFull%.*}

# Merge it with the "umbrella" command (like mrb)
fullCom="${mrb_command} $thisCom"

# Function to show command usage
function usage() 
{
  cat 1>&2 << EOF
Usage: $fullCom [-n | -p] [-f] [-b] [-T dir] [-S dir] [-B dir] [-P dir] [-v project_version] [-q qualifiers]
  Make a new development area by creating srcs, build, and products directories.
  Options:

     There are two development area configurations:
     1) srcs, build, and products all live within the same directory (the one 
          you are currently in now). This is the default.
     2) srcs, build, and products live in different areas of the filesystem. 
          This configuration is useful if you want to have your sources in your
          backed up home area with build and products in non-backed up scratch
          or some other area. For this configuration, the srcs area will be placed
          in yourcurrent directory. You use the -T, -B, and/or -P options (below)
	  to place the products and build areas elsewhere. 

     -S <dir>  = Where to put the source code directory (default is srcs in current directory)
     
     -T <dir>  = Where to put the build and localProducts directories (default is current directory next to srcs)

     -B <dir>  = Where to put the build directory (default is current directory next to srcs)

     -P <dir>  = Where to put the localProducts directory (default is current directory next to srcs)

     -v <version> = Build for this version instead of the default
     
     -q <qualifiers> = Build for these qualifiers instead of the default

     -b = Make a new build area corresponding to your machine flavor (development area already exists)

     These options are not typically used:
            -n = do not make the products area
            -p = just make the products area (checks that src, build are already there)
            -f = use a non-empty directory anyway
	    -d = print debugging info
EOF
}

function find_local_srcs()
{
    have_mrb_source="none"
    if ls -1 $srcTopDir | egrep -q '^srcs$';
      then 
	have_mrb_source=`cd $srcTopDir/srcs; pwd`
	if [ ${printDebug} ]; then echo "DEBUG: using srcTopDir/srcs"; fi
    fi
    if [ ${printDebug} ]; then echo "DEBUG: found local srcs directory ${have_mrb_source}"; fi
}

function make_srcs_directory()
{
  # Make directory
  cd ${currentDir}
  mkdir -p ${srcTopDir}/srcs
  # get the full path to the new directory
  cd ${srcTopDir}/srcs
  MRB_SOURCE=`pwd`
  cd ${currentDir}
  echo "MRB_SOURCE is ${MRB_SOURCE} "
  ##echo "NOTICE: Created srcs directory"

  # Make the main CMakeLists.txt file
  $MRB_DIR/libexec/copy_files_to_srcs.sh ${MRB_SOURCE} || exit 1
  if [ ${printDebug} ]; then echo "DEBUG: ran copy_files_to_srcs"; fi

  # Record the mrb version
  ups active | grep ^mrb >  ${MRB_SOURCE}/.mrbversion

}

function make_build_directory()
{
  # Make directories
  cd ${currentDir}

  # If we are just making a new build directory, we need to be were local products sits
  if [ ${doNewBuildDir} ]; then
    if ls -1 $topDir | egrep -q '^localProducts';
      then ok=1
      else echo 'ERROR: Your current directory must be where localProducts lives' ; exit 8
    fi 
  fi

  # Determine the subdirectory 
  # Using the function supplied by cetpkgsupport
  flav=`get-directory-name subdir`
  buildDirName="build_${flav}"

  # Make sure we don't already have the build directory
  if [ -d ${buildTopDir}/${buildDirName} ]; then
     echo "Build directory ${buildDirName} already exists"
  else
    mkdir -p ${buildTopDir}/${buildDirName}
    ##echo "Created build directory"
  fi
  # get the full path to the new directory
  cd ${buildTopDir}/${buildDirName}
  MRB_BUILDDIR=`pwd`
  cd ${currentDir}
  cd ${buildTopDir}
  fullBuildDir=`pwd`
  cd ${currentDir}
  echo "MRB_BUILDDIR is ${MRB_BUILDDIR}"
}

function make_localProducts_directory()
{
    # Prepare the setup script in @local_products@

    MRB_QUALS=${MRB_QUALS}

    # Construct the version and qualifier string
    qualdir=`echo ${MRB_QUALS} | sed s'/:/_/g'`
    if [ "$MRB_QUALS" = "-nq-" ]
    then
      dirVerQual="_${MRB_PROJECT}_${prjver}"
    else
      dirVerQual="_${MRB_PROJECT}_${prjver}_${qualdir}"
    fi
    # Construct the name of the @local_products@ directory
    # First get the full path 
    cd ${currentDir}
    cd ${lpTopDir}
    fullLPDir=`pwd`
    dirName="$fullLPDir/localProducts${dirVerQual}"
    MRB_INSTALL=${dirName}
    cd ${currentDir}

    #  Make sure the directory does not exist already
    if [ -e "$dirName" ]
    then
        echo "ERROR: $dirName already exists. Delete it first"
        exit 8
    fi

    # Make the local products directory
    mkdir -p $dirName || { echo "ERROR: failed to create $dirName"; exit 1; }
    ##echo "NOTICE: Created local products directory $dirName"

    # Record the mrb version
    echo "$MRB_VERSION" > ${dirName}/.mrbversion

    # Make a @.upsfiles@ directory for local products
    mkdir -p $dirName/.upsfiles || { echo "ERROR: failed to create $dirName/.upsfiles"; exit 1; }
    cp $MRB_DIR/templates/dbconfig $dirName/.upsfiles/ || { echo "ERROR: failed to copy dbconfig"; exit 1; }
    #cp -R $project_dir/.upsfiles $dirName
    ##echo "NOTICE: Copied .upsfiles to $dirName"
    
    if [ ${printDebug} ]
    then
        echo
	echo "DEBUG: MRB_SOURCE ${MRB_SOURCE}"
	echo "DEBUG: MRB_INSTALL ${MRB_INSTALL}"
	echo "DEBUG: prjdir ${prjdir}"
	echo "DEBUG: prjcodedir ${prjcodedir}"
    fi
    if [ ! -z ${prjdir} ] && [ -d ${prjdir} ]
    then
        $MRB_DIR/libexec/copy_dependency_database.sh ${MRB_SOURCE} ${MRB_INSTALL} ${MRB_PROJECTUC}_DIR
    elif [ ! -z ${prjcodedir} ] && [ -d ${prjcodedir} ] 
    then
       $MRB_DIR/libexec/copy_dependency_database.sh ${MRB_SOURCE} ${MRB_INSTALL} ${MRB_PROJECTUC}CODE_DIR
    else      
        ##echo "look for ${MRB_PROJECT} ${MRB_PROJECT_VERSION}"
	if ups exist ${MRB_PROJECT} ${MRB_PROJECT_VERSION} -q ${MRB_QUALS} >/dev/null 2>&1; then
            source `${UPS_DIR}/bin/ups setup -j ${MRB_PROJECT} ${MRB_PROJECT_VERSION} -q ${MRB_QUALS}`
            $MRB_DIR/libexec/copy_dependency_database.sh ${MRB_SOURCE} ${MRB_INSTALL} ${MRB_PROJECTUC}_DIR
	    unsetup -j ${MRB_PROJECT}
	elif ups exist ${MRB_PROJECT}code ${MRB_PROJECT_VERSION} -q ${MRB_QUALS} >/dev/null 2>&1; then
            source `${UPS_DIR}/bin/ups setup -j ${MRB_PROJECT}code ${MRB_PROJECT_VERSION} -q ${MRB_QUALS}`
            $MRB_DIR/libexec/copy_dependency_database.sh ${MRB_SOURCE} ${MRB_INSTALL} ${MRB_PROJECTUC}CODE_DIR
	    unsetup -j ${MRB_PROJECT}
	else
            echo "INFO: cannot find ${MRB_PROJECT}/${MRB_PROJECT_VERSION}/releaseDB/base_dependency_database"
            echo "      or ${MRB_PROJECT}code/${MRB_PROJECT_VERSION}/releaseDB/base_dependency_database"
	    echo "      mrb checkDeps and pullDeps will not have complete information"
	fi
    fi
}

function create_local_setup()
{
    # We want to avoid full paths, but we do need a full path for MRB_SOURCE
    # MRB_SOURCE might be in a completely different directory tree

    # copy the setup script
    cp $mrb_templates/local_setup  $dirName/setup
    
    # Write mrb_definitions

    # --- Start of HERE document for localProducts.../setup ---

    # --- Comments below pertain to that file ---
    cat >> $dirName/setup << EOF
setenv MRB_PROJECT "${MRB_PROJECT}"
setenv MRB_PROJECT_VERSION "${MRB_PROJECT_VERSION}"
setenv MRB_QUALS "${MRB_QUALS}"
setenv MRB_TOP "${fullTopDir}"
setenv MRB_TOP_BUILD "${fullBuildDir}"
setenv MRB_SOURCE "${MRB_SOURCE}"
setenv MRB_INSTALL "${MRB_INSTALL}"
setenv PRODUCTS "\${MRB_INSTALL}:\${PRODUCTS}"
setenv CETPKG_INSTALL "${MRB_INSTALL}"

EOF
# --- End of HERE document for localProducts.../setup ---

   cat $mrb_templates/local_mid  >> $dirName/setup

    # --- Start of HERE document for localProducts.../setup ---

    # --- Comments below pertain to that file ---
    cat >> $dirName/setup << EOF
# report the environment
echo
echo MRB_PROJECT=\$MRB_PROJECT
echo MRB_PROJECT_VERSION=\$MRB_PROJECT_VERSION
echo MRB_QUALS=\$MRB_QUALS
echo MRB_TOP=\$MRB_TOP
echo MRB_SOURCE=\$MRB_SOURCE
echo MRB_BUILDDIR=\$MRB_BUILDDIR
echo MRB_INSTALL=\$MRB_INSTALL
echo
echo PRODUCTS=\$PRODUCTS
echo CETPKG_INSTALL=\$CETPKG_INSTALL
echo

source "\$MRB_DIR/libexec/unset_shell_independence"
unset db buildDirName

EOF
# --- End of HERE document for localProducts.../setup ---

    # Display what we did (note the short HERE document)
    cat << EOF

IMPORTANT: You must type
    source $dirName/setup
NOW and whenever you log in

EOF

}

function copy_dependency_database() {
    prj_dir=$(printenv | grep ${1} | cut -f2 -d"=")
    if [ -e ${prj_dir}/releaseDB/base_dependency_database ]
    then
        cp -p ${prj_dir}/releaseDB/base_dependency_database ${MRB_INSTALL}/.base_dependency_database
    else 
        echo "INFO: cannot find ${prj_dir}/releaseDB/base_dependency_database"
	echo "      mrb checkDeps and pullDeps will not have complete information"
    fi
}

function check_qualList() {
    declare -a qualArray
    qualArray=$(echo ${qualList} | tr : " ")
    have_dop=false
    for qual in ${qualArray}
    do
       if [[ ${qual} == debug ]]; then have_dop=${qual}; fi
       if [[ ${qual} == opt ]]; then have_dop=${qual}; fi
       if [[ ${qual} == prof ]]; then have_dop=${qual}; fi
       if [[ ${qual} == -nq- ]]; then have_dop=${qual}; fi
    done
    if [[ ${have_dop} == false ]]
    then
       echo 
       echo "ERROR: build type is undefined"
       echo "ERROR: specified qualifiers are ${qualList}"
       echo "ERROR: One of debug, opt, or prof must be specified."
       exit 1
    fi
}

# Return success if any specified directory is not empty (ignoring MRB
# lock directories).
function dir_is_dirty()
{
  ls -1AF "$@" | grep -qvEe '^\.locks/$'
}

# Set up configuration
doForce=""
doNewBuildDir=""
topDir="."
topDirGiven="no"
srcTopDir="."
srcTopDirGiven="no"
currentDir=${PWD}
makeLP="yes"
makeBuild="yes"
makeSrcs="yes"
printDebug=""

# Process options
while getopts ":hdnfbpq:B:P:S:T:v:" OPTION
do
    case $OPTION in
        h   ) 
	    usage 
	    exit 0 
	    ;;
        d )
	    printDebug="yes"
	    ;;
        n   ) 
	    echo 'NOTICE: Will not make local products area' 
            makeLP=""
	    ;;
        p   ) 
	    echo 'NOTICE: Just make products area' 
	    makeBuild=""
            makeLP="yes"
	    makeSrcs=""
	    ;;
        b   )
            echo 'NOTICE: Just make build directory corresponding to this machine flavor'
            doNewBuildDir="yes"
            makeBuild="yes"
            makeLP=""
            makeSrcs=""
            doForce="yes"
            ;;
        f   ) 
	    doForce="yes"
	    ;;
        B   ) 
	    echo "NOTICE: build area be under $OPTARG" 
            topDirGiven="yes"
	    buildTopDir=$OPTARG 
	    ;;
        P   ) 
	    echo "NOTICE: localPproducts area be under $OPTARG" 
            topDirGiven="yes"
	    lpTopDir=$OPTARG 
	    ;;
        S   ) 
	    echo "NOTICE: source code srcs will be under $OPTARG" 
            srcTopDirGiven="yes"
	    srcTopDir=$OPTARG 
	    ;;
        T   ) 
	    echo "NOTICE: localPproducts and build areas will go to $OPTARG" 
            topDirGiven="yes"
	    topDir=$OPTARG 
	    ;;
        v   ) 
	    ##echo "NOTICE: building for $OPTARG"
	    thisVersion=$OPTARG 
	    ;;
        q   ) 
	    ##echo "NOTICE: using $OPTARG qualifiers"
	    qualList=$OPTARG 
	    ;;
	:   ) 
	    echo "ERROR: -$OPTARG requires an argument"
	    usage
	    exit 1 
	    ;;
        ?   ) 
	    echo "ERROR: Unknown option -$OPTARG" 
	    usage 
	    exit 1 
	    ;;
    esac
done

# Some sanity checks -

# Make sure we have ups
if [ -z ${UPS_DIR} ]
then
   echo "ERROR: please setup ups"
   exit 1
fi
source `${UPS_DIR}/bin/ups setup ${SETUP_UPS}`

# report current set of flags
if [ ${printDebug} ]
then
    echo "DEBUG: doForce     is ${doForce}"
    echo "DEBUG: topDir      is ${topDir}"
    echo "DEBUG: srcTopDir   is ${srcTopDir}"
    echo "DEBUG: currentDir  is ${currentDir}"
    echo "DEBUG: makeLP      is ${makeLP}"
    echo "DEBUG: makeBuild   is ${makeBuild}"
    echo "DEBUG: makeSrcs    is ${makeSrcs}"
fi

# Make sure the @MRB_PROJECT@ product is setup
if [ -z ${MRB_PROJECT} ]
then
    echo "ERROR: MRB_PROJECT is not defined."
    echo "       Please set \${MRB_PROJECT} to the main product (e.g., larsoft, uboone, etc.)"
    exit 2
fi
MRB_PROJECTUC=`echo ${MRB_PROJECT} | tr '[:lower:]' '[:upper:]'`
prjvername="${MRB_PROJECTUC}_VERSION"
oldprjver="${!prjvername}"
if [ -z ${thisVersion} ]
then
    prjver="${oldprjver}"
else
    prjver="${thisVersion}"
fi
prjdirname="${MRB_PROJECTUC}_DIR"
prjdir="${!prjdirname}"
MRB_PROJECT_VERSION=${prjver}
prjcodename="${MRB_PROJECTUC}CODE_DIR"
prjcodedir="${!prjcodename}"
if [ ${printDebug} ]
then
    echo "DEBUG: MRB_PROJECTUC ${MRB_PROJECTUC}"
    echo "DEBUG: prjver ${prjver}"
    echo "DEBUG: prjdirname ${prjdirname}"
    echo "DEBUG: prjdir ${prjdir}"
    echo "DEBUG: prjcodename ${prjcodename}"
    echo "DEBUG: prjcodedir ${prjcodedir}"
fi
if [ -z ${prjdir} ] && [ -z ${qualList} ]
then
    echo "ERROR: ${MRB_PROJECT} product is not setup."
    echo "       You must EITHER setup the desired version of ${MRB_PROJECT} OR specify the qualifiers"
    echo "       e.g., mrb newDev -v vX_YY_ZZ -q e17:debug"
    exit 2
fi
# now sort out the qualifier list
if [ -z ${qualList} ]
then
    # Let's figure out where the product lives
    project_dir=$(dirname ${prjdir} | xargs dirname )

    # Determine the quailfier (replace : with -)
    setupname="SETUP_${MRB_PROJECTUC}"
    project_qual=$(echo ${!setupname} | cut -d' ' -f8)

    # Replace : with _ in directory
    prjqual=$(echo $project_qual | tr : _)

    MRB_QUALS=${project_qual}
else
    check_qualList
    project_dir=$(dirname ${UPS_DIR} | xargs dirname | xargs dirname )
    if [[ ${qualList} == -nq- ]]; then
    MRB_QUALS=${qualList}
    else
    MRB_QUALS=`echo ${qualList} | sed s'/-/:/g'`
    fi
fi

echo
echo "building development area for ${MRB_PROJECT} ${MRB_PROJECT_VERSION} -q ${MRB_QUALS}"
echo


# Make sure we aren't off of a build or srcs directory...

# Get current directory with "/" at the end
pwda="$(pwd)/"
if [ ${printDebug} ]; then echo "DEBUG: pwda is ${pwda}"; fi

# Are we within srcs?
if pwd | egrep -q '/srcs[^/]*$';
    then echo 'ERROR: Cannot be within a srcs directory' ; exit 3
fi

# Are we within build?
if pwd | egrep -q '/build[^/]*$';
  then echo 'ERROR: Cannot be within a build directory' ; exit 4
fi

# Are we within localProducts?
if pwd | egrep -q '/localProducts[^/]*$';
  then echo 'ERROR: Cannot be within a localProducts directory' ; exit 4
fi

if [ -z "${buildTopDir}" ]; then buildTopDir=${topDir}; fi
if [ -z "${lpTopDir}" ]; then lpTopDir=${topDir}; fi

echo
echo "The following configuration is defined:"
echo "  The top level directory is ${topDir}"
echo "  The source code directory will be under ${srcTopDir}"
echo "  The build directory will be under ${buildTopDir}"
echo "  The local product directory will be under ${lpTopDir}"
echo

# Continue the sanity checks
# make sure the directories we are about to create are empty

if [ ${makeSrcs} ]
then
    # Make sure the source directory is empty (e.g. leave room for @srcs/@)
    if [ -d ${srcTopDir} ] && dir_is_dirty "$srcTopDir"; then

        # Directory has stuff in it, error unless force option is given.
        if [ ! $doForce ]; then
            echo 'ERROR: source code directory has stuff in it!'
            echo '   You should make a new empty directory or add -f to use this one anyway'
            exit 5
        fi
    fi
fi

if [ ${makeBuild} ]
then
     # Make sure the directory for build is empty
    if [ "$buildTopDir" != "$srcTopDir" ] && [ -d ${buildTopDir} ] && dir_is_dirty "$buildTopDir"; then

      # Directory has stuff in it, error unless force option is given.
      if [ ! $doForce ]; then
        echo 'ERROR: Directory for build has stuff in it!'
	echo "   Attempting to use ${buildTopDir}"
        echo '   You should make a new empty directory there or add -f to use that directory anyway'
        exit 6
      fi
    fi
fi

if [ ${makeLP} ]
then
     # Make sure the directory for build and local products is empty
    if [ "$lpTopDir" != "$srcTopDir" ] && [ -d ${lpTopDir} ] && dir_is_dirty "$lpTopDir"; then

      # Directory has stuff in it, error unless force option is given.
      if [ ! $doForce ]; then
        echo 'ERROR: Directory for build and localProducts has stuff in it!'
	echo "   Attempting to use ${lpTopDir}"
        echo '   You should make a new empty directory there or add -f to use that directory anyway'
        exit 6
      fi
    fi
fi

# If we're just making the localProducts area, then we MUST be where build lives
if [ ${makeLP} ] && [ ! ${makeBuild} ]
then
    if [ ${printDebug} ]; then echo "DEBUG: buildTopDir is ${buildTopDir}"; fi
    if ls -1 $buildTopDir | egrep -q '^build';
      then ok=1
      else echo 'ERROR: No build directory. Must be in a development area with build to make localProducts' ; exit 7
    fi
fi

# Finally done with the sanity checks

# h3. Build area
#  Do we need to make the @build/@ directory?
if [ ${makeBuild} ]
then
    make_build_directory
else
    # If we are not making the build area, then we MUST know where build lives
    if ls -1 $topDir | egrep -q '^build';
      then ok=1
      else echo 'ERROR: No build directory. Must be in a development area with build to make localProducts' ; exit 7
    fi
    echo "use existing build directory in $topDir"
fi

# h3. Srcs area
#  Do we need to make the @srcs/@ directory?
if [ ${makeSrcs} ]
then
  # Do we already have a srcs directory?
  find_local_srcs
  if [ "${have_mrb_source}" = "none" ]
  then
      make_srcs_directory
  elif [ ${doForce} ]
  then
      MRB_SOURCE=${have_mrb_source}
  else
      echo "ERROR: unable to create srcs directory"
      exit 6
  fi
else
    # If we are not making the srcs area, then we MUST know where srcs lives
    if ls -1 $topDir | egrep -q '^srcs$';
      then 
        ok=1
	MRB_SOURCE=`cd $topDir/srcs; pwd`
	if [ ${printDebug} ]; then echo "DEBUG: using topDir/srcs"; fi
    elif ls -1 $srcTopDir | egrep -q '^srcs$';
      then 
        ok=1
	MRB_SOURCE=`cd $srcTopDir/srcs; pwd`
	if [ ${printDebug} ]; then echo "DEBUG: using srcTopDir/srcs"; fi
    elif [ ${MRB_SOURCE} ];
      then 
        ok=1
	if [ ${printDebug} ]; then echo "DEBUG: using MRB_SOURCE"; fi
    else
        echo 'ERROR: Cannot find existing srcs directory. '
	exit 7
    fi
    echo "use existing srcs directory ${MRB_SOURCE}"
fi

# h3. Local Products area
# Create local products area if necessary
if [ ${makeLP} ]; then
    make_localProducts_directory

    # get full top dir
    cd ${currentDir}
    cd ${topDir}
    fullTopDir=`pwd`
    if [ -z ${fullBuildDir} ]; then
      cd ${currentDir}
      cd ${buildTopDir}
      fullBuildDir=`pwd`
      cd ${currentDir}
    fi
    if [ ${printDebug} ]; then
      echo "DEBUG: fullTopDir is ${fullTopDir}"
      echo "DEBUG: fullBuildDir is ${fullBuildDir}"
    fi

    create_local_setup

fi

exit 0
