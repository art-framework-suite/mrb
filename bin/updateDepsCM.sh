#!/usr/bin/env bash

# Update the master CMakeLists.txt file with whatever is found in $MRB_SOURCE

# No arguments

# Determine the name of this command
thisComFull=$(basename $0)
thisCom=${thisComFull%.*}
fullCom="${mrb_command} $thisCom"

# Function to show command usage
function usage() {
  cat 1>&2 << EOF
Usage: $fullCom
  Update the CMakeLists.txt file with the latest versions of dependencies.

  Options:
     -b = Copy CMakeLists.txt to CMakeLists.txt.bak first (backup)
EOF
}

doBak=""

# Determine command options (just -h for help)
while getopts ":hbf:" OPTION
do
    case $OPTION in
        h   ) usage ; exit 0 ;;
        b   ) doBak="yes" ;;
        *   ) echo "ERROR: Unknown option" ; usage ; exit 1 ;;
    esac
done

# Some sanity checks -
if [ -z "${MRB_SOURCE}" ]
then
    echo 'ERROR: MRB_SOURCE must be defined'
    echo '       source the appropriate localProductsXXX/setup'
    exit 1
fi

if [ ! -r $MRB_SOURCE/CMakeLists.txt ]; then
    echo "$MRB_SOURCE/CMakeLists.txt not found"
    exit 1
fi

# Backup?
if [ $doBak ]; then
  cp $MRB_SOURCE/CMakeLists.txt $MRB_SOURCE/CMakeLists.txt.bak
  cp $MRB_SOURCE/.cmake_add_subdir $MRB_SOURCE/.cmake_add_subdir.bak
  cp $MRB_SOURCE/.cmake_include_dirs $MRB_SOURCE/.cmake_include_dirs.bak
fi

# find the directories
# ignore any directory that does not contain ups/product_deps
list=$(ls -d $MRB_SOURCE/*/ 2>/dev/null)
for file in $list
do
  if [ -r ${file}ups/product_deps ]
  then
    pkglist+=($(basename $file))
  fi
done

ordered_pkglist=($(sed -ne 's&^# >> \(.*\) <<$&\1&p' \
  "${MRB_BUILDDIR}/${MRB_PROJECT}-${MRB_PROJECT_VERSION}" 2>/dev/null))

if (( ${#ordered_pkglist[@]} == ${#pkglist[@]} )); then
  # We have the same *number* of packages -- are they the same packages?
  TMP=`mktemp -t updateDepsCM.sh.XXXXXX`
  trap "rm $TMP* 2>/dev/null" EXIT
  (IFS=$'\n'; printf '%s\n' "${ordered_pkglist[*]}") | sort > "${TMP}_ordered.txt"
  (IFS=$'\n'; printf '%s\n' "${pkglist[*]}") | sort > "${TMP}.txt"
  cmp "${TMP}.txt" "${TMP}_ordered.txt" && (( want_ordered = 1 ))
fi
if (( want_ordered )); then
  pkglist=("${ordered_pkglist[@]}")
else
  cat <<EOF
updateDepsCM: Unable to guarantee correct ordering of package clauses in
              CMakeLists.txt. Re-run mrb uc after a successful mrbsetenv.
EOF
fi

echo ""
echo "updateDepsCM: rewrite $MRB_SOURCE/CMakeLists.txt"
echo "              for these packages:"
printf "        "
if (( ${#pkglist[*]} )); then
  echo "${pkglist[@]}"
else
  echo "<none>"
fi
echo ""

# Construct a new CMakeLists.txt file in srcs
${MRB_DIR}/bin/copy_files_to_srcs.sh ${MRB_SOURCE} || exit $?

# Add back the packages
if (( ${#pkglist[*]} )); then
  ${MRB_DIR}/bin/add_to_cmake.sh ${MRB_SOURCE} "${pkglist[*]}"
fi

exit $?
