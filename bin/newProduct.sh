#!/usr/bin/env bash

# Set up a new product. This involves several things,
# * Creating a directory structure by resolving templates for CMakeLists.txt and various files in the UPS area
# * Adding this product to the top level CMakeLists.txt file
# * Initialize git
# * Initialize git flow

# Some templates are specific to each project
# look for $MRB_SOURCE/$MRB_PROJECT/$MRB_PROJECT_VERSION/templates
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

# Create the necessary directories and files
function createFiles() {

  PRODNAME=$1
  daNoFlav=$2

  noflav=""
  if [ "$daNoFlav" = "yes" ]; then
    noflav="yes"
  fi
  
  # Find default qualifier
  DQ=`echo ${MRB_QUALS} | sed -e 's/debug//' -e 's/opt//' -e 's/prof//' -e 's/::/:/g' -e 's/:$//g' -e 's/^://'`
  ##echo "DEBUG: default qualifier is $DQ"
  
  echo ${MRB_QUALS} | grep -q e5
  have_e5=$?
  echo ${MRB_QUALS} | grep -q e6
  have_e6=$?
  if [ ${have_e6} = 0 ]
  then
     CETBV=v4_03_00
     GCCV=v4_9_1
     EXTRAFLAG=""  # Lynn had ) here, which can't work in my template
  elif [ ${have_e5} = 0 ]
  then
     CETBV=v3_13_01
     GCCV=v4_8_2
     EXTRAFLAG="EXTRA_CXX_FLAGS -std=c++11 )"
  else
     CETBV=v3_07_11
     GCCV=v4_8_1
     CHECK_GCC="cet_check_gcc()"
     EXTRAFLAG="EXTRA_CXX_FLAGS -std=c++11 )"
  fi
  ##echo "DEBUG: cetbuildtools version is $CETBV"
  ##echo "DEBUG: gcc version is $GCCV"

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
    templateDir=${MRB_SOURCE}/${MRB_PROJECT}/${MRB_PROJECT_VERSION}/templates
  elif [ -d $(eval echo \$${pkgdirnm}/templates ) ]
  then
    templateDir=$(eval echo \$${pkgdirnm}/templates )
  else
    templateDir=${MRB_DIR}/templates/product
  fi

  # Let's start filling in templates
  echo "-- Filling templates from ${templateDir}"

  # Top level @CMakeLists.txt@ file from &l=templates/product/CMakeLists.txt_top&
  if [ "$noflav" ]; then
    sed -e "s/%%PD%%/$PD/g" -e "s/%%PU%%/$PU/g" < ${templateDir}/CMakeLists.txt_top_noflav > CMakeLists.txt
  else
    sed -e "s/%%PD%%/$PD/g" -e "s/%%PU%%/$PU/g" -e "s/%%CHECK_GCC%%/$CHECK_GCC/g" -e "s/%%EXTRAFLAG%%/$EXTRAFLAG/g" < ${templateDir}/CMakeLists.txt_top > CMakeLists.txt
  fi

  # @$PRODNAME/CMakeLists.txt@ file 
  mkdir $PRODNAME
  # this is really simple, just write it
  echo "# basic source code CMakeLists.txt" > $PRODNAME/CMakeLists.txt
  if [ "$noflav" ]; then
    echo "" >> $PRODNAME/CMakeLists.txt
  else
    echo "" >> $PRODNAME/CMakeLists.txt
    echo "art_make( )" >> $PRODNAME/CMakeLists.txt
    echo "" >> $PRODNAME/CMakeLists.txt
    echo "install_headers()" >> $PRODNAME/CMakeLists.txt
    echo "install_source()" >> $PRODNAME/CMakeLists.txt
  fi
  echo "install_fhicl()" >> $PRODNAME/CMakeLists.txt

  # @test/CMakeLists.txt@ file from &l=templates/product/CMakeLists.txt_test&
  mkdir test
  sed -e "s/%%PD%%/$PD/g" -e "s/%%PU%%/$PU/g" < ${templateDir}/CMakeLists.txt_test > test/CMakeLists.txt

  # @ups@ directory
  mkdir ups
  cd ups

  # @ups/CMakeLists.txt@ file 
  # this is another simple file
  echo "# create package configuration and version files" > CMakeLists.txt
  echo "" >> CMakeLists.txt
  echo "process_ups_files()" >> CMakeLists.txt
  echo "" >> CMakeLists.txt
  if [ "$noflav" ]; then
    echo "cet_cmake_config( NO_FLAVOR )" >> CMakeLists.txt
  else
    echo "cet_cmake_config()" >> CMakeLists.txt
  fi
  echo "" >> CMakeLists.txt

  # ups files

  cp ${templateDir}/product-config.cmake.in.template product-config.cmake.in

  # From &l=templates/product/product_deps&
  if [ "$noflav" ]; then
    input_product_deps=${templateDir}/product_deps_noflav
  else
    input_product_deps=${templateDir}/product_deps
    cp ${templateDir}/setup_deps.template setup_deps
  fi
  sed -e "s/%%PD%%/$PD/g" -e "s/%%PU%%/$PU/g" -e "s/%%DQ%%/$DQ/g" -e "s/%%CETBV%%/$CETBV/g" -e "s/%%GCCV%%/$GCCV/g" -e "s/%%PROJECT%%/$MRB_PROJECT/g" -e "s/%%PV%%/$MRB_PROJECT_VERSION/g" < ${input_product_deps} > product_deps

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
      ${MRB_DIR}/bin/add_to_cmake.sh ${MRB_SOURCE} ${PRODNAME} || exit 1;
  fi

  echo "Complete - Product $PRODNAME was created"

  echo "Your next tasks: "
  echo "                Check $PRODNAME/ups/product_deps"
  echo "                Check $PRODNAME/CMakeLists.txt file"
  echo "                Add code in $PRODNAME/$PRODNAME"
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

if [ -z "${MRB_SOURCE}" ]
then
    echo 'ERROR: MRB_SOURCE must be defined'
    echo '       source the appropriate localProductsXXX/setup'
    exit 1
fi

#   Are we in the source area?
if echo $PWD | egrep -q "/srcs$";
  then
    ok=1
  else
    echo 'ERROR: You must be in your srcs directory'
  exit 7
fi

mrb_bin=${MRB_DIR}/bin

# If we want to create the files
if [ $create ]; then createFiles $PRODNAME $noflav; fi
