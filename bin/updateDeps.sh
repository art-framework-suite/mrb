#!/usr/bin/env bash

# Update the product_deps file with the latest versions of dependencies
    
# No arguments

# Determine the name of this command
thisComFull=$(basename $0)
thisCom=${thisComFull%.*}

# Merge it with the "umbrella" command (like gm2d)
fullCom="$umbCom $thisCom"

# Function to show command usage
function usage() {
  cat 1>&2 << EOF
Usage: $fullCom 
  Update product_deps and CMakeLists.txt files for new versions of dependencies that you have already set up.
  You must have the new versions set up as well as having already run ". mrb setEnv" and/or ". mrb setup_local_products".
  By default, this command updates every package you have checked out in $MRB_SOURCE.
  If you want to only update a particular package, use the -p option.

  Options:
          -d = do a dry run -- print out what would change without actually changing any files
          -p <package> = Only update <package> in $MRB_SOURCE (default is to do all checked out)
          -R = Restore the old CMakeLists.txt and product_deps files from git

EOF
}

dryRun="no"
restore="no"
package="--all--"

# Determine command options (just -h for help)
while getopts ":hdRp:" OPTION
do
    case $OPTION in
        h   ) usage ; exit 0 ;;
        d   ) dryRun="yes" ; echo 'DRY RUN - Changes are not saved';;
        R   ) restore="yes" ;; 
        p   ) package=$OPTARG ;;
        *   ) echo "ERROR: Unknown option" ; usage ; exit 1 ;;
    esac
done

# Loop over directories in $MRB_SOURCE
packages=$(ls -d $MRB_SOURCE/*/)
if [ "$package" != "--all--" ]; then
  packages=$MRB_SOURCE/$package
fi

for d in $packages
do
  # Sanity checks
  if [ ! -r $d/CMakeLists.txt ]; then echo "Cannot find CMakeLists.txt in $d"; break; fi
  if [ ! -r $d/ups/product_deps ]; then echo "Cannot find ups/product_deps in $d"; break; fi

  if [ $restore == "no" ]
  then
 
      echo " "
      echo "Updating $d ...."

      python $MRB_DIR/bin/update_deps_productdeps.py $d/ups/product_deps $dryRun
      python $MRB_DIR/bin/update_deps_cmakeliststxt.py $d/CMakeLists.txt $dryRun
  
  else
      echo "Restoring $d"
      pushd $d > /dev/null
      rm -f CMakeLists.txt
      git checkout CMakeLists.txt
      rm -f ups/product_deps
      git checkout ups/product_deps
      popd > /dev/null
  fi

done

if [ $restore == "yes" ]; then
  echo 'Be sure to re-run . mrb setEnv'
fi

exit 0
