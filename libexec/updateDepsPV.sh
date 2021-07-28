#!/usr/bin/env bash

# Update the product_deps file with the specified version of a product
    
# No arguments

# Determine the name of this command
thisComFull=$(basename $0)
thisCom=${thisComFull%.*}
fullCom="$mrb_command $thisCom"

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
  have_dep="$(sed -Ene '/^product[[:space:]]+version\b/,/^end_product_list/ { /^'"$product"'\b/ { p ; q; }; }' "$pdfile" || :)"
  if [ -n "$have_dep" ]; then
    echo "INFO: updating $product version for dependent $pkg_name in $pdfile"
  elif [ "$pkg_name" = "$product" ]; then
    echo "INFO: updating $product version in $pdfile"
  else
    return 0
  fi
  (( ++updated_files ))
  "$MRB_DIR/libexec/edit_product_deps" "$pdfile" $product $new_version $dryRun
}

function modify_cmake()
{
  local cfile=$1
  echo "INFO: updating $product version in $cfile"
  (( ++updated_files ))
  "$MRB_DIR/libexec/edit_cmake" "$cfile" $product $new_version $dryRun
}

function get_package_list()
{
  local dir OIFS IFS
  OIFS="$IFS"
  IFS=$'\n'
  local pkglist=($(ls -1d $MRB_SOURCE/*/))
  IFS="$OIFS"
  for dir in "${pkglist[@]}"; do
    while [[ "$dir" == */ ]] ; do
      dir="${dir%/}"
    done
    [ -r "$dir/ups/product_deps" ] && pkg_dirs+=("$dir")
  done
}

dryRun="no"
restore="no"

# Determine command options (just -h for help)
while getopts ":hdRp:" OPTION
do
    case $OPTION in
        h   ) usage ; exit 0 ;;
        d   ) dryRun="yes" ; echo 'DRY RUN: changes are not saved';;
        R   ) restore="yes" ;; 
        *   ) echo "ERROR: Unknown option" ; usage ; exit 1 ;;
    esac
done

(( updated_files = 0 ))
failed=()
if [ $restore == "yes" ]; then
  operation="restore"
  get_package_list
  for pkg_dir in "${pkg_dirs[@]}"; do
    pkg_name="$(sed -Ene 's&^[[:space:]]*parent[[:space:]]+([^[:space:]\#]+).*&\1&p; T; q' "${pdfile}")"
    pdfile="$pkg_dir/ups/product_deps"
    # Sanity checks
    if [ -e "$pkg_dir/.git" ]; then
      echo "INFO: restoring $pkg_dir"
      if pushd "$pkg_dir" > /dev/null; then
        git checkout -qf -- ups/product_deps || \
          {
          echo "WARNING: unable to restore ups/product_deps for $pkg_name in $pkg_dir" 1>&2
          failed+=($pkg_name)
        }
        popd > /dev/null
      else
        echo "WARNING: unable to change directory to $pkg_dir to restore ups/product_deps" 1>&2
        failed+=($pkg_name)
      fi
    else
      echo "WARNING: unable to restore ups/product_deps from non-git repository $pkg_dir" 1>&2
      failed+=($pkg_name)
    fi
  done
else
  operation="update"

  # Did the user provide a product name?
  shift $((OPTIND - 1))
  if [ $# -lt 1 ]; then
    echo "ERROR: no product given" 1>&2
    usage 1>&2
    exit 1
  fi

  # Capture the product name
  product=$1

  # check for version
  if [ $# -lt 2 ]; then
    echo "ERROR: no version given" 1>&2
    usage 1>&2
    exit 1
  fi
  new_version=$2

  get_package_list

  for pkg_dir in "${pkg_dirs[@]}"; do
    pdfile="$pkg_dir/ups/product_deps"
    pkg_name="$(sed -Ene 's&^[[:space:]]*parent[[:space:]]+([^[:space:]\#]+).*&\1&p; T; q' "${pdfile}")"
    # Sanity checks
    if [ ! -r "$pkg_dir"/CMakeLists.txt ]; then
      echo "WARNING: cannot find CMakeLists.txt in $pkg_dir" 1>&2
      false
    elif [ ! -r "$pdfile" ]; then
      echo "WARNING: cannot find ups/product_deps in $pkg_dir" 1>&2
      false
    else
      modify_product_deps "$pfdile" && \
        { if [ "$pkg_name" = "$product" ]; then \
        modify_cmake "$pkg_dir/CMakeLists.txt"; fi; } && \
        { cmf="$pkg_dir"/releaseDB/CMakeLists.txt; \
        if [ -r "$cmf" ] && grep -Ee '\b'"$product"'\b' "$cmf" >/dev/null 2>&1; then \
        modify_cmake "$cmf"; fi; } && \
        { cmf="$pkg_dir"/bundle/CMakeLists.txt; \
        if [ -r "$cmf" ] && grep -Ee '\b'"$product"'\b' "$cmf" >/dev/null 2>&1; then \
        modify_cmake "$cmf"; fi; }
    fi
    (( $? == 0 )) || failed+=($pkg_name)
  done
fi

echo
if [ -n "${failed[*]}" ]; then
  printf "ERROR: $operation failed for packages:\n         ${failed[*]}\n" 1>&2
  status=1
else
  status=0
fi

if [ "$dryRun" = "yes" ]; then
  echo "INFO: if the dry run was successful, run: "
  echo " mrb uv $product $new_version"
else
  (( updated_files == 1 )) && plural='' || plural='s'
  (( updated_files )) && action=': be sure to re-run mrbsetenv'
  printf "INFO: updated %d file%s%s\n" "$updated_files" "$plural" "$action"
fi

exit $status
