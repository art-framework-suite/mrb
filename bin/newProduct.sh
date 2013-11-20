#!/usr/bin/env bash

# Set up a new product. This involves several things,
# * Creating a directory structure by resolving templates for CMakeLists.txt and various files in the UPS area
# * Adding this product to the top level CMakeLists.txt file
# * Initialize git
# * Initialize git flow

# Some templates are specific to each project
# look for $MRB_SOURCE/$MRB_PROJECT/$MRB_VERSION/templates
# if not found, look for $MRB_PROJECT_DIR/templates
# if that fails, use our templates

# Determine the name of this command
thisComFull=$(basename $0)
thisCom=${thisComFull%.*}

# Merge it with the "umbrella" command (like gm2d)
fullCom="${mrb_command} $thisCom"

# Function to show command usage
function usage() {
  cat 1>&2 << EOF
Usage: $fullCom [-c -n] product_name
Make a new product from scratch. You have to supply the name of the product.

Options:
   -c Just create files (do not initialize for git)
   -n Create a "no-flavor" product (e.g. nothing to compile)
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

# Create the necessary directories and files
function createFiles() {

  PRODNAME=$1
  daNoFlav=$2

  noflav=""
  if [ "$daNoFlav" = "yes" ]; then
    noflav="yes"
  fi

  # Check that the product name is all lowercase and no punctuation
  if echo $PRODNAME | egrep -q '[^a-z0-9]'; then
    echo "ERROR: $PRODNAME must be all lowercase and no punctuation"
    exit 4
  fi

  # Do we already have this directory?
  if [ -d $PRODNAME ]; then
    echo "ERROR: $PRODNAME directory already exists!"
    exit 2
  fi

  # Ok - we are good to go here!
  echo "-- Creating new product $PRODNAME"

  # Make the directory and cd into it
  mkdir $PRODNAME
  cd $PRODNAME

  # Create upper and lowercase product names
  PD=$(echo $PRODNAME | tr 'A-Z' 'a-z')
  PU=$(echo $PRODNAME | tr 'a-z' 'A-Z')
  
  # find the template directory
  pkgdirnm=$(echo $MRB_PROJECT | tr 'a-z' 'A-Z')_DIR
  if [ -d ${MRB_SOURCE}/${MRB_PROJECT}/templates ]
  then
    templateDir=${MRB_SOURCE}/${MRB_PROJECT}/${MRB_VERSION}/templates
  elif [ -d $(eval echo \$${pkgdirnm}/templates ) ]
  then
    templateDir=$(eval echo \$${pkgdirnm}/templates )
  else
    templateDir=${mrb_dir}/../templates/product
  fi

  # Let's start filling in templates
  echo "-- Filling templates from ${templateDir}"

  # Top level @CMakeLists.txt@ file from &l=templates/product/CMakeLists.txt_top&
  if [ "$noflav" ]; then
    sed -e "s/%%PD%%/$PD/g" -e "s/%%PU%%/$PU/g" < ${templateDir}/CMakeLists.txt_top_noflav > CMakeLists.txt
  else
    sed -e "s/%%PD%%/$PD/g" -e "s/%%PU%%/$PU/g" < ${templateDir}/CMakeLists.txt_top > CMakeLists.txt
  fi

  # @test/CMakeLists.txt@ file from &l=templates/product/CMakeLists.txt_test&
  mkdir test
  sed -e "s/%%PD%%/$PD/g" -e "s/%%PU%%/$PU/g" < ${templateDir}/CMakeLists.txt_test > test/CMakeLists.txt

  # @ups@ directory
  mkdir ups
  cd ups

  # @ups/CMakeLists.txt@ file from &l=templates/product/CMakeLists.txt_ups&
  sed -e "s/%%PD%%/$PD/g" -e "s/%%PU%%/$PU/g" < ${templateDir}/CMakeLists.txt_ups > CMakeLists.txt

  # ups files

  # From &l=templates/product/pkg-config-version.cmake.in&
  sed -e "s/%%PD%%/$PD/g" -e "s/%%PU%%/$PU/g" < ${templateDir}/pkg-config-version.cmake.in > ${PD}-config-version.cmake.in

  # From &l=templates/product/pkg-config.cmake.in&
  sed -e "s/%%PD%%/$PD/g" -e "s/%%PU%%/$PU/g" < ${templateDir}/pkg-config.cmake.in > ${PD}-config.cmake.in

  # From &l=templates/product/product_deps&
  if [ "$noflav" ]; then
    sed -e "s/%%PD%%/$PD/g" -e "s/%%PU%%/$PU/g" < ${templateDir}/product_deps_noflav > product_deps
  else
    sed -e "s/%%PD%%/$PD/g" -e "s/%%PU%%/$PU/g" < ${templateDir}/product_deps > product_deps
  fi

  # From &l=templates/product/setup_for_development&
  if [ "$noflav" ]; then
    sed -e "s/%%PD%%/$PD/g" -e "s/%%PU%%/$PU/g" < ${templateDir}/setup_for_development_noflav > setup_for_development
  else
    sed -e "s/%%PD%%/$PD/g" -e "s/%%PU%%/$PU/g" < ${templateDir}/setup_for_development > setup_for_development
  fi

  # Get out of ups directory
  cd ..

  if [ $gitinit ]
  then
    # Do the basic git initialization
    echo "-- Initialize git repository and git-flow"
    git init >> /dev/null 2>&1
    git flow init -d >> /dev/null 2>&1
  fi

  # Get out of this product and back to @srcs/@
  cd ..

  # Add lines to the top level @CMakeLists.txt@ file (e.g. the one in @srcs/@)
  echo "-- Updating top CMakeLists.txt"
  if [ ! -w "CMakeLists.txt" ]; then
    echo 'ERROR: No CMakeLists.txt file'
    exit 6
  fi

  # Is this product already in the top @CMakeLists.txt@?
  if grep -q \($PRODNAME\) CMakeLists.txt
    then
      echo "-- NOTICE: project is already in CMakeLists.txt file"
    else
      # No - add it
      cp ${MRB_DIR}/templates/CMakeLists.txt.master CMakeLists.txt || exit 1;
      # have to accumulate the include_directories command in one fragment
      # and the add_subdirectory commands in another fragment
      pkgname=`grep parent ${MRB_SOURCE}/${PRODNAME}/ups/product_deps  | grep -v \# | awk '{ printf $2; }'`
      echo "# ${PRODNAME} package block" >> cmake_include_dirs
      echo "set(${pkgname}_not_in_ups true)" >> cmake_include_dirs
      echo "include_directories ( \${CMAKE_CURRENT_SOURCE_DIR}/${PRODNAME} )" >> cmake_include_dirs
      cat cmake_include_dirs >> CMakeLists.txt
      echo ""  >> CMakeLists.txt
      echo "ADD_SUBDIRECTORY($PRODNAME)" >> cmake_add_subdir
      cat cmake_add_subdir >> CMakeLists.txt
      echo ""  >> CMakeLists.txt
      echo "NOTICE: Added $PRODNAME to CMakeLists.txt file"
  fi

  echo "Complete - Product $PRODNAME is set for the develop branch"

  echo "Your next task: Create directory for sources and add to CMakeLists.txt file"
}

# Process options
create="yes"
gitinit="yes"
noflav="no"
while getopts ":hcrn" OPTION
do
  case $OPTION in
    h   ) usage ; exit 0 ;;
    c   ) echo 'NOTICE: Will only create files'; gitinit="" ;;
    n   ) echo 'NOTICE: You are making a no-flavor product'; noflav="yes" ;;
    *   ) echo "ERROR: Unknown option" ; usage ; exit 1 ;;
  esac
done

# Capture the new product name
# Are there any options left?
shift $((OPTIND - 1))
if [ ! $# == 1 ]; then 
  echo 'ERROR: You must provide a product name'
  usage
  exit 1
fi

PRODNAME=$1

#   Are we in the source area?
if echo $PWD | egrep -q "/srcs$";
  then
    ok=1
  else
    echo 'ERROR: You must be in your srcs directory'
  exit 7
fi

get_mrb_bin

# If we want to create the files
if [ $create ]; then createFiles $PRODNAME $noflav; fi
