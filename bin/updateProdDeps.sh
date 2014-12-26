#!/usr/bin/env bash

# Update the product_deps file with dependencies from local products
    
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
          Update product dependencies in product_deps according to what is in the local products.
          It changes the version dependencies to match what is in product_deps. Note that this only
          updates versions, not qualifiers. If a qualifier has changed, the build will not work. This command
          is used by superbuild.
EOF
}


# Determine command options (just -h for help)
while getopts ":h" OPTION
do
    case $OPTION in
        h   ) usage ; exit 0 ;;
        *   ) echo "ERROR: Unknown option" ; usage ; exit 1 ;;
    esac
done

python $MRB_DIR/bin/update_deps_localproducts.py

exit 0
