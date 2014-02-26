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
Usage: $fullCom newVersion newQualifier
  Update the product_deps file with the latest versions of dependencies and with a new version number
  and qualifier for your product. If this product has no qualifier, then use '-nq-' for the qualifier.

  Options:
     -b = Copy product_deps to product_deps.bak first (backup)
     -f = Specify the file (default is product_deps)
EOF
}

f="product_deps"
doBak=""

# Determine command options (just -h for help)
while getopts ":hbf:" OPTION
do
    case $OPTION in
        h   ) usage ; exit 0 ;;
        b   ) doBak="yes" ;;
        f   ) f=$OPTARG ;;
        *   ) echo "ERROR: Unknown option" ; usage ; exit 1 ;;
    esac
done

# Backup?
if [ $doBak ]; then
  cp $f ${f}.bak
fi

shift $((OPTIND - 1))

if [ $# -ne 2 ]; then
    echo 'ERROR: No arguments given'
    usage
    exit 1
fi

# Some sanity checks -
if [ ! -r product_deps ]; then
    echo 'product_deps not found'
    exit 1
fi

python $thisDirA/update_deps_productdeps.py $f $1 $2

exit 0
