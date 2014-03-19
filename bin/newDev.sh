#!/usr/bin/env bash

# Set up a new development area.
# * Create a srcs directory for source code
# * Create a top build area
# * Create a local products area
# * Construct a @setup@ script in local products

# Within the srcs area is a top level @CMakeLists.txt@ file so that, if you want, you can
# build everything in @srcs@. It also makes a main @setEnv@ script. 

# The local products area directory name has the version and qualifier of @${MRB_PROJECT}@ that you
# currently have set up. It also makes a setup script in there that is necessary to set up
# to use this products area. 

# Determine the name of this command
thisComFull=$(basename $0)
thisCom=${thisComFull%.*}

# Merge it with the "umbrella" command (like mrb)
fullCom="${mrb_command} $thisCom"

# Function to show command usage
function usage() 
{
  cat 1>&2 << EOF
Usage: $fullCom [-n | -p] [-f] [-b] [-T dir] [-S dir] [-v project_version] [-q qualifiers]
  Make a new development area by creating srcs, build, and products directories.
  Options:

     There are two development area configurations:
     1) srcs, build, and products all live within the same directory (the one 
          you are currently in now). This is the default.
     2) srcs, build, and products live in different areas of the filesystem. 
          This configuration is useful if you want to have your sources in your
          backed up home area with build and products in non-backed up scratch
          or some other area. For this configuration, the srcs area will be placed in your
          current directory along with a set up script. You use the -T option (below) 
          to place the products and build areas elsewhere. 

     -S <dir>  = Where to put the source code directory (default is srcs in current directory)
     
     -T <dir>  = Where to put the build and localProducts directories (default is current directory next to srcs)
    
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

function make_srcs_directory()
{
  # Make directory
  cd "${currentDir}"
  mkdir -p "${srcTopDir}/srcs"
  # get the full path to the new directory
  cd "${srcTopDir}/srcs"
  MRB_SOURCE="`/bin/pwd`"
  cd "${currentDir}"
  echo "MRB_SOURCE is ${MRB_SOURCE} "
  echo "NOTICE: Created srcs directory"

  # Make the main CMakeLists.txt file
  ${mrb_bin}/copy_files_to_srcs.sh "${MRB_SOURCE}" || exit 1
  # this is a hack....
  cp "${mrb_bin}/../templates/dependency_list" "${MRB_SOURCE}/" || exit 1;
  # end hack

  # Make the top setEnv script (this is more complicated, so we'll just copy it from
  # @templates@). See &l=templates/setEnv& for the template
  cp "${mrb_bin}/../templates/setEnv" "${MRB_SOURCE}/setEnv"
  if [ -e "${MRB_SOURCE}/setEnv" ]
  then
    chmod a+x "${MRB_SOURCE}/setEnv"
    echo "NOTICE: Created ${MRB_SOURCE}/setEnv"
  else
    echo "ERROR: failed to create ${MRB_SOURCE}/setEnv"
    exit 9
  fi

  # If we're on MacOSX, then copy the xcodeBuild.sh file
  if ups flavor -1 | grep -q 'Darwin'
  then
    cp "${mrb_bin}/../templates/xcodeBuild.sh" "${MRB_SOURCE}/xcodeBuild.sh"
    chmod a+x "${MRB_SOURCE}/xcodeBuild.sh"
    echo "NOTICE: Created ${MRB_SOURCE}/xcodeBuild.sh"
  fi
}

# Set up configuration
doForce=""
doNewBuildDir=""
topDir="."
srcTopDir="."
currentDir=${PWD}
makeLP="yes"
makeBuild="yes"
makeSrcs="yes"
printDebug=""

# Process options
while getopts ":hdnfbpq:S:T:v:" OPTION
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
        S   ) 
	    echo "NOTICE: source code srcs will go into $OPTARG" 
	    srcTopDir=$OPTARG 
	    ;;
        T   ) 
	    echo "NOTICE: localPproducts and build areas will go to $OPTARG" 
	    topDir=$OPTARG 
	    ;;
        v   ) 
	    echo "NOTICE: building for $OPTARG"
	    thisVersion=$OPTARG 
	    ;;
        q   ) 
	    echo "NOTICE: using $OPTARG qualifiers"
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

#get_mrb_bin
( cd / ; /bin/pwd -P ) >/dev/null 2>&1
if (( $? == 0 )); then
    pwd_P_arg="-P"
fi
reldir=`dirname ${0}`
mrb_bin=`cd ${reldir} && /bin/pwd ${pwd_P_arg}`

if [ ${printDebug} ]
then
    echo "DEBUG: mrb_dir: ${mrb_dir}"
    echo "DEBUG: mrb_bin: ${mrb_bin}"
fi


# Make sure the @MRB_PROJECT@ product is setup
if [ -z ${MRB_PROJECT} ]
then
    echo "ERROR: MRB_PROJECT is not defined."
    echo "       Please set \${MRB_PROJECT} to the master product (e.g., larsoft, uboone, etc.)"
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
if [ -z ${prjdir} ] && [ -z ${qualList} ]
then
    echo "ERROR: ${MRB_PROJECT} product is not setup."
    echo "       You must EITHER setup the desired version of ${MRB_PROJECT} OR specify the qualifiers"
    echo "       e.g., mrb newDev -v vX_YY_ZZ -q e2:debug"
    echo "       Available versions of ${MRB_PROJECT}:"
    ups list -aK+ ${MRB_PROJECT}
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
    project_dir=$(dirname ${UPS_DIR} | xargs dirname | xargs dirname )
    MRB_QUALS=${qualList}
fi

echo "building development area for ${MRB_PROJECT} ${prjver}"


# Make sure we aren't off of a build or srcs directory...

# Get current directory with "/" at the end
pwda="$(pwd)/"
if [ ${printDebug} ]; then echo "DEBUG: pwda is ${pwda}"; fi

# Are we within srcs?
if echo $pwda | grep -q '/srcs[^/]*$';
    then echo 'ERROR: Cannot be within a srcs directory' ; exit 3
fi

# Are we within build?
if echo $pwda | grep -q '/build[^/]*$';
  then echo 'ERROR: Cannot be within a build directory' ; exit 4
fi

# make sure the directories we are about to create are empty

if [ ${makeSrcs} ]
then
    # Make sure the source directory is empty (e.g. leave room for @srcs/@)
    if [ -d ${srcTopDir} ] && [ "$(ls -A ${srcTopDir})" ]; then

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
     # Make sure the directory for build and local products is empty
    if [ "$topDir" != "$srcTopDir" ] && [ -d ${topDir} ] && [ "$(ls -A $topDir)" ]; then

      # Directory has stuff in it, error unless force option is given.
      if [ ! $doForce ]; then
        echo 'ERROR: Directory for build and localProducts has stuff in it!'
        echo '   You should make a new empty directory there or add -f to use that directory anyway'
        exit 6
      fi
    fi
fi

# If we're just making the localProducts area, then we MUST be where build lives
if [ ${makeLP} ] && [ ! ${makeBuild} ]
then
    if ls -1 $topDir | egrep -q '/build[^/]*$';
      then ok=1
      else echo 'ERROR: No build directory. Must be in a development area with build to make localProducts' ; exit 7
    fi
fi

# Record the mrb version
# But we might create more here later, so should this be in the localProducts and srcs areas?
ups active | grep '^mrb' > "${currentDir}/.mrbversion"

# h3. Build area
#  Do we need to make the @build/@ directory?
if [ ${makeBuild} ]
then
  # Make directories
  cd "${currentDir}"

  # If we are just making a new build directory, we need to be were local products sits
  if [ ${doNewBuildDir} ]; then
    if ls -1 "${topDir}" | egrep -q '^localProducts'
    then
      ok=1
    else
      echo 'ERROR: Your current directory must be where localProducts lives'
      exit 8
    fi 
  fi

  # Determine the subdirectory 
  # Using the function supplied by cetpkgsupport
  flav=`get-directory-name subdir`
  buildDirName="build_${flav}"

  # Make sure we don't already have the build directory
  if [ -d "${topDir}/${buildDirName}" ]
  then
     echo "Build directory ${buildDirName} already exists"
  else
    mkdir -p "${topDir}/${buildDirName}"
    echo "Created build directory"
  fi
  # get the full path to the new directory
  cd "${topDir}/${buildDirName}"
  MRB_BUILDDIR="`/bin/pwd`"
  cd "${currentDir}"
  echo "MRB_BUILDDIR is ${MRB_BUILDDIR}"
else
  # Determine the subdirectory 
  # Using the function supplied by cetpkgsupport
  flav=`get-directory-name subdir`
  buildDirName="build_${flav}"

  # If we are not making the build area, then we MUST know where build lives
  if ls -1 "${topDir}" | egrep -q "/${buildDirName}\$";
    then ok=1
    else echo 'ERROR: No build directory. Must be in a development area with build to make localProducts' ; exit 7
  fi
  # get the full path to the new directory
  cd "${topDir}/${buildDirName}"
  MRB_BUILDDIR="`/bin/pwd`"
  cd "${currentDir}"
  echo "MRB_BUILDDIR is ${MRB_BUILDDIR}"
  echo "use existing build directory in $topDir"
fi

# h3. Srcs area
#  Do we need to make the @srcs/@ directory?
if [ ${makeSrcs} ]
then
    # Do we already have a srcs directory?
    have_mrb_source="none"
    if ls -1 "${srcTopDir}" | egrep -q '^srcs$';
    then 
        have_mrb_source=`cd "${srcTopDir}/srcs"; /bin/pwd`
	if [ ${printDebug} ]
        then
            echo "DEBUG: using ${srcTopDir}/srcs"
        fi
    fi
    if [ ${printDebug} ]
    then
        echo "DEBUG: found local srcs directory ${have_mrb_source}"
    fi
    if [ "${have_mrb_source}" = "none" ]
    then
        make_srcs_directory
    elif [ ${doForce} ]
    then
        MRB_SOURCE="${have_mrb_source}"
    else
        echo "ERROR: unable to create srcs directory"
        exit 6
    fi
else
    # If we are not making the srcs area, then we MUST know where srcs lives
    if ls -1 "${topDir}" | egrep -q '^srcs$'
    then 
        ok=1
	MRB_SOURCE=`cd "${topDir}/srcs"; /bin/pwd`
	if [ ${printDebug} ]
        then
            echo "DEBUG: using ${topDir}/srcs"
        fi
    elif ls -1 "${srcTopDir}" | egrep -q '^srcs$'
    then 
        ok=1
	MRB_SOURCE=`cd "${srcTopDir}/srcs"; /bin/pwd`
	if [ ${printDebug} ]
        then
            echo "DEBUG: using ${srcTopDir}/srcs"
        fi
    elif [ ${MRB_SOURCE} ]
    then 
        ok=1
	if [ ${printDebug} ]
        then
            echo "DEBUG: using MRB_SOURCE: ${MRB_SOURCE}"
        fi
    else
        echo 'ERROR: Cannot find existing srcs directory. '
	exit 7
    fi
    echo "use existing srcs directory ${MRB_SOURCE}"
fi

# h3. Local Products area
# Create local products area if necessary
if [ ${makeLP} ]; then
    # Prepare the setup script in @local_products@

    # Construct the call for the setup
    if [ `ups exist "${MRB_PROJECT}" "${prjver}" -q "${MRB_QUALS}"` ]
    then
        setupLine="setup \"${MRB_PROJECT}\" \"${prjver}\" -q \"${MRB_QUALS}\""
    else
        setupLine="setup \"${MRB_PROJECT}\" \"${oldprjver}\" -q \"${MRB_QUALS}\""
    fi

    # Construct the version and qualifier string
    qualdir=`echo "${MRB_QUALS}" | sed s'/:/_/g'`
    dirVerQual="${MRB_PROJECT}_${prjver}_${qualdir}"
    # Construct the name of the @local_products@ directory
    # First get the full path 
    cd "${topDir}"
    fullTopDir="`/bin/pwd`"
    cd "${currentDir}"
    MRB_INSTALL="${fullTopDir}/localProducts_${dirVerQual}"

    #  Make sure the directory does not exist already
    if [ -e "${MRB_INSTALL}" ]
    then
        echo "ERROR: ${MRB_INSTALL} already exists. Delete it first"
        exit 8
    fi

    # Make the local products directory
    mkdir -p "${MRB_INSTALL}"
    echo "NOTICE: Created local products directory ${MRB_INSTALL}"


    # Copy the @.upsfiles@ directory to local products
    cp -R ${project_dir}/.upsfiles "${MRB_INSTALL}"
    echo "NOTICE: Copied .upsfiles to ${MRB_INSTALL}"

    # copy the setup script
    cp "${mrb_bin}/../templates/local_setup" "${MRB_INSTALL}/setup"
    
    # Write mrb_definitions

    # --- Start of HERE document for localProducts.../setup ---

    # --- Comments below pertain to that file ---
    cat >> "${MRB_INSTALL}/setup" << EOF
setenv MRB_SOURCE "${MRB_SOURCE}"
setenv MRB_BUILDDIR "${MRB_BUILDDIR}"
setenv MRB_INSTALL "${MRB_INSTALL}"
setenv MRB_PROJECT "${MRB_PROJECT}"
setenv MRB_PROJECT_VERSION ${MRB_PROJECT_VERSION}
setenv MRB_QUALS "${MRB_QUALS}"
setenv PRODUCTS "${MRB_INSTALL}:\${PRODUCTS}"

# report the environment
echo
echo MRB_SOURCE=\$MRB_SOURCE
echo MRB_BUILDDIR=\$MRB_BUILDDIR
echo MRB_INSTALL=\$MRB_INSTALL
echo MRB_PROJECT=\$MRB_PROJECT
echo MRB_PROJECT_VERSION=\$MRB_PROJECT_VERSION
echo MRB_QUALS=\$MRB_QUALS
echo
echo PRODUCTS=\$PRODUCTS
echo

##$setupLine
##echo Executed $setupLine

test "$ss" = csh && unalias tnotnull nullout set_ vecho_ unsetenv_
unset ss sts msg1 msg2 db me
unset set_ setenv unsetenv_ tnotnull source nullout ovexe ov vecho_

EOF
# --- End of HERE document for localProducts.../setup ---

    # Display what we did (note the short HERE document)
    cat << EOF
NOTICE: Created ${MRB_INSTALL}/setup

IMPORTANT: You must type
    source ${MRB_INSTALL}/setup
NOW and whenever you log in
EOF

#end of if [ ${makeLP} ]
fi

exit 0
