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
Usage: $fullCom [-n | -p] [-f] [-T dir] [-V project_version] [-Q qualifiers]
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

     -T <dir>  = Where to put the build and localProducts directories (default is current directory next to srcs)
     
     -V <version> = Build for this version instead of the default
     
     -Q <qualifiers> = Build for these qualifiers instead of the default

     These options are not typically used:
            -n = do not make the products area
            -p = just make the products area (checks that src, build are already there)
            -f = use a non-empty directory anyway
EOF
}

function get_mrb_bin()
{
    ( cd / ; /bin/pwd -P ) >/dev/null 2>&1
    if (( $? == 0 )); then
      pwd_P_arg="-P"
    fi
    reldir=`dirname ${0}`
    mrb_bin=`cd ${reldir} && /bin/pwd ${pwd_P_arg}`
}

function create_master_cmake_file()
{
  # Make the main CMakeLists.txt file (note the use of a here documents)
  cp ${mrb_bin}/../templates/CMakeLists.txt.master srcs/CMakeLists.txt || exit 1;
  echo 'NOTICE: Created srcs/CMakeLists.txt'
}

function create_local_setup()
{
    # Write the setup script

    # --- Start of HERE document for localProducts.../setup ---

    # --- Comments below pertain to that file ---
    cat > $dirName/setup << EOF
#!/usr/bin/env bash
# Setup script (source it)

# Make sure this script is sourced
if [[ \${BASH_SOURCE[0]} == "\${0}" ]]; then
  echo "You must source this script. e.g. source setup"
  exit 1
fi

# Determine where this script is running
thisDirAB=\$(cd \${BASH_SOURCE[0]%/*} && echo \$PWD/\${BASH_SOURCE[0]##*/} )
thisDirA=\`dirname \$thisDirAB\`

# Source the basic setup script
source $project_dir/setup >> /dev/null 2>&1

# Add this products area to the @PRODUCTS@ path
export PRODUCTS=\$thisDirA:$PRODUCTS

# Set the @MRB_INSTALL@ environment variable
export MRB_INSTALL=\$thisDirA

# Set the convience @SRCS@ environment variable
export SRCS=$PWD/srcs

# Set up @${MRB_PROJECT}@
export MRB_PROJECT=${MRB_PROJECT}
export MRB_BUILDDIR=${MRB_BUILDDIR}
export MRB_VERSION=${MRB_VERSION}
export MRB_QUALS=${MRB_QUALS}
setup mrb
##$setupLine
##echo Executed $setupLine
EOF
# --- End of HERE document for localProducts.../setup ---

    # Make sure we make the script executable
    chmod a+x $dirName/setup

    # Display what we did (note the short HERE document)
    cat << EOF
NOTICE: Created $dirName/setup

IMPORTANT: You must type
    source $dirName/setup
NOW and whenever you log in
EOF

}

# Set up configuration
doLP="yes"
justLP=""
doForce=""
topDir="."
buildDirTop="."
currentDir=${PWD}

# Process options
while getopts ":hnfpQ:T:V:" OPTION
do
    case $OPTION in
        h   ) usage ; exit 0 ;;
        n   ) echo 'NOTICE: Will not make local products area' ; doLP="" ;;
        p   ) echo 'NOTICE: Just make products area' ; justLP="yes" ;;
        f   ) doForce="yes";;
        Q   ) echo "NOTICE: using $OPTARG qualifiers"; qualList=$OPTARG ;;
        T   ) echo "NOTICE: localPproducts and build areas will go to $OPTARG" ; topDir=$OPTARG ;;
        V   ) echo "NOTICE: building for $OPTARG"; thisVersion=$OPTARG ;;
	:   ) echo "ERROR: -$OPTARG requires an argument"; usage; exit 1 ;;
        ?   ) echo "ERROR: Unknown option -$OPTARG" ; usage ; exit 1 ;;
    esac
done

# Some sanity checks -

# Make sure we have ups
if [ -z ${UPS_DIR} ]
then
   echo "ERROR: please setup ups"
   exit 1
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
MRB_VERSION=${prjver}
if [ -z ${prjdir} ] && [ -z ${qualList} ]
then
    echo "ERROR: ${MRB_PROJECT} product is not setup."
    echo "       You must EITHER setup the desired version of ${MRB_PROJECT} OR specify the qualifiers"
    echo "       e.g., mrb newDev -V ${prjver} -Q e2:debug"
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

get_mrb_bin

##echo ${mrb_dir}
##echo ${mrb_bin}

# Are we within srcs?
if echo $pwda | grep -q '/srcs/';
    then echo 'ERROR: Cannot be within a srcs directory' ; exit 3
fi

# Are we within build?
if echo $pwda | grep -q '/build/';
  then echo 'ERROR: Cannot be within a build directory' ; exit 4
fi

# If we need to make @srcs/@ and @build/@ directories, make sure they aren't there already
if [ ! $justLP ];
  then
    # Make sure the current directory is empty (e.g. leave room for @srcs/@)
    if [ "$(ls -A .)" ]; then

        # Directory has stuff in it, error unless force option is given.
        if [ ! $doForce ]; then
            echo 'ERROR: Current directory has stuff in it!'
            echo '   You should make a new empty directory or add -f to use this one anyway'
            exit 5
        fi
    fi

    # Make sure the directory for build and local products is empty
    if [ "$topDir" != "." ] && [ "$(ls -A $topDir)" ]; then

      # Directory has stuff in it, error unless force option is given.
      if [ ! $doForce ]; then
        echo 'ERROR: Directory for build and localProducts has stuff in it!'
        echo '   You should make a new empty directory there or add -f to use that directory anyway'
        exit 6
      fi
    fi
  else

    # If we're just making the localProducts area, then we MUST to be where build lives
    if ls -1 $topDir | egrep -q '^build$';
      then ok=1
      else echo 'ERROR: No build directory. Must be in a development area with build to make localProducts' ; exit 7
    fi

fi

# h3. Srcs and Build areas
# If we are supposed to, then set up the @srcs/@ and @build/@ directories
if [ ! $justLP ];  then

  # Make directories
  mkdir srcs
  mkdir $topDir/build
  MRB_BUILDDIR=${currentDir}/build
  echo "MRB_BUILDDIR is ${currentDir}/build"
  echo 'NOTICE: Created srcs and build directories'

  create_master_cmake_file

  # Make the top setEnv script (this is more complicated, so we'll just copy it from
  # @templates@). See &l=templates/setEnv& for the template
  cp ${mrb_dir}/../templates/setEnv srcs/setEnv
  if [ -e srcs/setEnv ]
  then
    chmod a+x srcs/setEnv
    echo 'NOTICE: Created srcs/setEnv'
  else echo 'ERROR: failed to create srcs/setEnv'; exit 9
  fi

  # If we're on MacOSX, then copy the xcodeBuild.sh file
  if ups flavor -1 | grep -q 'Darwin'; then
    cp ${mrb_dir}/../templates/xcodeBuild.sh srcs/xcodeBuild.sh
    chmod a+x srcs/xcodeBuild.sh
    echo 'NOTICE: Created srcs/xcodeBuild.sh'
  fi

fi

# h3. Local Products area
# Create local products area if necessary
if [ $doLP ]; then
    # Prepare the setup script in @local_products@

    # Construct the call for the setup
    if [ `ups exist ${MRB_PROJECT} ${prjver} -q ${MRB_QUALS}` ]
    then
        setupLine="setup ${MRB_PROJECT} ${prjver} -q \"${MRB_QUALS}\""
    else
        setupLine="setup ${MRB_PROJECT} ${oldprjver} -q \"${MRB_QUALS}\""
    fi
    MRB_QUALS=${MRB_QUALS}

    # Construct the version and qualifier string
    qualdir=`echo ${MRB_QUALS} | sed s'/:/_/'`
    dirVerQual="_${MRB_PROJECT}_${prjver}_${qualdir}"
    # Construct the name of the @local_products@ directory
    dirName="$topDir/localProducts${dirVerQual}"

    #  Make sure the directory does not exist already
    if [ -e "$dirName" ]
    then
        echo "ERROR: $dirName already exists. Delete it first"
        exit 8
    fi

    # Make the local products directory
    mkdir $dirName
    echo "NOTICE: Created local products directory $dirName"


    # Copy the @.upsfiles@ directory to local products
    cp -R $project_dir/.upsfiles $dirName
    echo "NOTICE: Copied .upsfiles to $dirName"

    create_local_setup

fi
