#!/usr/bin/env bash

# Update the product_deps file with the specified version of a product
    
# No arguments

# Determine the name of this command
thisComFull=$(basename $0)
thisCom=${thisComFull%.*}
fullCom="${mrb_command} $thisCom"

# Function to show command usage
function usage() 
{
  cat 1>&2 << EOF
Usage: $fullCom <product> <version>
  Update ups/product_deps.
  Change the version of <product> to <version> 
  This command updates every package you have checked out in $MRB_SOURCE.

  Options:
          -d = do a dry run -- print out what would change without actually changing any files
          -R = Restore the old product_deps files from git

EOF
}

function modify_product_deps()
{
  local pkg=$1
  
  pdfile=${pkg}/ups/product_deps
  pkg_name="$(sed -Ene 's&^[[:space:]]*parent[[:space:]]+([^[:space:]\#]+).*&\1&p; T; q' "${pdfile}")"

  echo "updating dependencies for ${pkg_name} in ${pdfile}"
  $MRB_DIR/libexec/edit_product_deps ${pdfile} ${product} ${new_version} ${dryRun}  || exit 1
}

function modify_cmake()
{
  local cfile="$1"
  echo "editing $cfile"
  grep -Ee '\b'"${product}"'\b' "${cfile}"
  $MRB_DIR/libexec/edit_cmake "${cfile}" ${product} ${new_version} ${dryRun}  || exit 1
  grep -Ee '\b'"${product}"'\b' "${cfile}"
}

function get_package_list()
{
  local file OIFS IFS
  OIFS="$IFS"
  IFS=$'\n'
  local pkglist=($(ls -1d $MRB_SOURCE/*/))
  IFS="$OIFS"
  for dir in "${pkglist[@]}"; do
    while [[ "$dir" == */ ]] ; do
      dir="${dir%/}"
    done
    [ -r "$dir/ups/product_deps" ] && packages+=("$dir")
  done
}

dryRun="no"
restore="no"

# Determine command options (just -h for help)
while getopts ":hdRp:" OPTION
do
    case $OPTION in
        h   ) usage ; exit 0 ;;
        d   ) dryRun="yes" ; echo 'DRY RUN - Changes are not saved';;
        R   ) restore="yes" ;; 
        *   ) echo "ERROR: Unknown option" ; usage ; exit 1 ;;
    esac
done

if [ $restore == "yes" ]; then
  get_package_list
  for d in "${packages[@]}"; do
    # Sanity checks
    if [ ! -r "$d/ups/product_deps" ]; then
      echo "Cannot find ups/product_deps in $d"
      break
    fi
    echo "Restoring $d"
    pushd "$d" > /dev/null
    git checkout -qf -- ups/product_deps
    popd > /dev/null
  done
  exit 0
fi

# Did the user provide a product name?
shift $((OPTIND - 1))
if [ $# -lt 1 ]; then
    echo "ERROR: No product given"
    usage
    exit 1
fi

# Capture the product name
product=$1

# check for version
if [ $# -lt 2 ]; then
    echo "ERROR: No version given"
    usage
    exit 1
fi
new_version=$2

get_package_list

for d in "${packages[@]}"; do
  # Sanity checks
  if [ ! -r "${d}"/CMakeLists.txt ]; then echo "Cannot find CMakeLists.txt in ${d}"; break; fi
  if [ ! -r "${d}"/ups/product_deps ]; then echo "Cannot find ups/product_deps in ${d}"; break; fi
  modify_product_deps "${d}"
  if [ -r "${d}"/releaseDB/CMakeLists.txt ]; then modify_cmake "${d}/releaseDB/CMakeLists.txt"; fi
  if [ -r "${d}"/bundle/CMakeLists.txt ]; then modify_cmake "${d}/bundle/CMakeLists.txt"; fi
done

echo
if [ "${dryRun}" = "yes" ]; then
  echo "If the dry run was successful, run: "
  echo " mrb uv ${product} ${new_version}"
else
  echo 'Be sure to re-run mrbsetenv'
fi

exit 0
