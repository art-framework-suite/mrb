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
  Update the product_deps file of a package with a new version number (changes the "parent" line).

  Options:
     -L = Increment the last number; e.g. v0_0_1 -> v0_0_2
     -M = Increment the middle number; e.g. v0_0_1 -> v0_1_0
     -F = Increment the first number; e.g. v0_0_1 -> v1_0_0
     -S = Set the version number; e.g. "-S v55_0_22"; v0_0_1 -> v55_0_22
     -t = Add text after the version number; e.g. "-L -t hi": v0_0_1 -> v0_0_2_hi
     -q = Change the qualifier (optional)
     -b = Copy product_deps to product_deps.bak first (backup)
     -f = Specify the file (default is product_deps)

     You must specify one of -L, -M, -F, -S or -t (-t may be combined with others)
EOF
}

f="product_deps"
doBak=""
number="--none--"
doText="--none--"
doQual="--none--"

# Determine command options (just -h for help)
while getopts ":hbLMFS:f:t:q:" OPTION
do
    case $OPTION in
        h   ) usage ; exit 0 ;;
        b   ) doBak="yes" ;;
        f   ) f=$OPTARG ;;
        L   ) if [ $number == "--none--" ]; then number="--last--"; else usage; exit 0; fi ;;
        M   ) if [ $number == "--none--" ]; then number="--middle--"; else usage; exit 0; fi ;;
        F   ) if [ $number == "--none--" ]; then number="--first--"; else usage; exit 0; fi ;;
        S   ) if [ $number == "--none--" ]; then number=$OPTARG; else usage; exit 0; fi ;;
        t   ) doText=$OPTARG ;;
        q   ) doQual=$OPTARG ;;
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

if [ "$number" == "--none--" ] && [ "$doText" == "--none--" ]; then usage; exit 0; fi

shift $((OPTIND - 1))

if [ $# -ne 1 ]; then
    echo 'ERROR: No package name given or you forgot an argument to an option'
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

python $MRB_DIR/bin/bumpVersion.py $1 $pdfile $number $doText $doQual

exit 0
