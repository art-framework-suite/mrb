#!/usr/bin/env bash

# Bump the version number of a package

# No arguments

# Determine the name of this command
thisComFull=$(basename $0)
thisCom=${thisComFull%.*}

# Merge it with the "umbrella" command (like gm2d)
fullCom="$umbCom $thisCom"

# Function to show command usage
function usage() {
  cat 1>&2 << EOF
Usage: $fullCom package [options]
  Update the product_deps file of a package with a new version. 

  Options:
     -L = Increment the last number; e.g. v0_0_1 -> v0_0_2
     -M = Increment the middle number; e.g. v0_0_1 -> v0_1_0
     -F = Increment the first number; e.g. v0_0_1 -> v1_0_0
     -S = Set the version number; e.g. "-S v55_0_22"; v0_0_1 -> v55_0_22
     -t = Add text after the version number; e.g. "-L -t hi": v0_0_1 -> v0_0_2_hi
     -q = Change the qualifier (optional)
     -b = Copy product_deps to product_deps.bak first (backup)
     -f = Specify the file (default is product_deps)

     You may specify only one of -L, -M, -F, and -S
EOF
}

f="product_deps"
doBak=""
number=""
doText="--none--"
doQual="--none--"

# Determine command options (just -h for help)
while getopts ":hbf:LMFt:q:" OPTION
do
    case $OPTION in
        h   ) usage ; exit 0 ;;
        b   ) doBak="yes" ;;
        f   ) f=$OPTARG ;;
        L   ) if [-z $number]; then number="--last--"; else usage; exit 0; fi ;;
        M   ) if [-z $number]; then number="--middle--"; else usage; exit 0; fi ;;
        F   ) if [-z $number]; then number="--first--"; else usage; exit 0; fi ;;
        S   ) if [-z $number]; then number=$OPTARG; else usage; exit 0; fi ;;
        t   ) doText=$OPTARG ;;
        q   ) doQual=$OPTARG ;;
        *   ) echo "ERROR: Unknown option" ; usage ; exit 1 ;;
    esac
done

if [-z $number]; then usage; exit 0

shift $((OPTIND - 1))

if [ $# -ne 2 ]; then
    echo 'ERROR: No arguments given'
    usage
    exit 1
fi

# Does the file exist?
pdfile=$MRB_SOURCE/$1/ups/$f

if [ ! -r $pdfile ]; then
    echo "$pdfile not found"
    exit 1
fi

# Backup?
if [ $doBak ]; then
  cp $pdfile ${pdfile}.bak 
fi

python $thisDirA/bumpVersion.py $1 $pdfile $number $doText $doQual

exit 0
