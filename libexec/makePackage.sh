#!/usr/bin/env bash

# use DESTDIR to define a temporary install directory
# use temporary install directory structure to determine tarball names

# Determine the name of this command
thisComFile="${0##*/}"
thisCom="${thisComFile%.*}"

# Merge it with the "umbrella" command (like mrb)
fullCom="${mrb_command} $thisCom"

# Function to show command usage
function usage() 
{
  cat 1>&2 << EOF
Usage: $fullCom [options] [-- options for cmake --build]
  Make distribution tarballs for each product installed by this build
  Options:
     -n <distribution_name> = the name for the manifest (e.g., uboone, lbne, ...)
         If unspecified, this defaults to MRB_PROJECT
     -v <version> = the version for the manifest (vx_y_z format)
         If unspecified, this defaults to MRB_PROJECT_VERSION
     -j <ncores> = pass along the -j flag to cmake --build for backwards compatibility
  -- signals the end of the options for ${thisCom}
  
  For instance: mrb mp -m xyz -- -j4	 
	
EOF
}

# set defaults
distribution_name=${MRB_PROJECT}
distribution_version=${MRB_PROJECT_VERSION}
jcores=""

# Determine command options (just -h for help)
while getopts "hj:n:v:" OPTION
do
    case $OPTION in
        h   ) usage ; exit 0 ;;
        n   ) distribution_name=$OPTARG ;;
        v   ) distribution_version=$OPTARG ;;
	j   ) jcores="-j $OPTARG" ;;
        *   ) echo "ERROR: Unknown option" ; usage ; exit 1 ;;
    esac
done
shift $((OPTIND - 1))

if [ -z "${MRB_BUILDDIR}" ]
then
  echo "ERROR in ${thisCom}: MRB_BUILDDIR is not defined."
  echo '       source the appropriate localProductsXXX/setup'
  exit 1
fi

# define the temporary install directory and make sure it is empty
temp_install_path="${MRB_BUILDDIR}"/tempinstall
rm -rf "${temp_install_path}"

# Cleanup at end.
trap "rm -rf \"$temp_install_path\" >/dev/null 2>&1" EXIT

# run a redirected install
env DESTDIR="${temp_install_path}" \
    cmake --build "${MRB_BUILDDIR}" $jcores -t install "$@" || \
  { echo "ERROR in $thisCom: redirected temporary install failed" 1>&2
    exit 1; }

thisos=`get-directory-name os`
myflvr=`ups flavor -4`
myOS=`uname -s`
if [ ${myOS} = "Darwin" ]
then
    myflvr=`ups flavor -2`
fi
myqualdir=`echo ${MRB_QUALS} | sed s'/:/-/g'`
mydotver=`echo ${distribution_version} |  sed -e 's/_/./g' | sed -e 's/^v//'`
manifest=${distribution_name}-${mydotver}-${myflvr}-${myqualdir}_MANIFEST.txt
rm -f ${manifest}
touch ${manifest}

echo "create manifest ${manifest}"

# full path to products
temp_products="${temp_install_path}${MRB_INSTALL}"

# make this a real products area
ln -s "$MRB_INSTALL/.upsfiles" "$temp_products" || \
  { echo 1>&2 <<EOF
ERROR in $thisCom: unable to link $temp_products/.upsfiles -> $MRB_INSTALL/.upsfiles
EOF
    exit 1; }

# loop over products and make tarballs
ups list -aK+ -z "$temp_products" | sed -Ene 's&^"([^"]+)".*$&\1&p' | while read thisprod; do
  thisver=`ls ${temp_products}/${thisprod} | grep -v version`
  thisdotver=`echo ${thisver} | sed -e 's/_/./g' | sed -e 's/^v//'`
  proddirs=("${temp_products}/${thisprod}/${thisver}/${thisos}"*)
  if [ -d "${proddirs[*]}" ]; then
    flvrdir=`ls -d "${temp_products}/${thisprod}/${thisver}/${thisos}"*`
    thisflvr=${flvrdir##*/}
    tarflvr=${thisflvr//./-}
    tarballname="${thisprod}-${thisdotver}-${tarflvr}.tar.bz2"
  else
    tarballname="${thisprod}-${thisdotver}-noarch.tar.bz2"
  fi
  echo "making ${tarballname}"
  tar -C "${temp_products}" -cjf "${MRB_BUILDDIR}/${tarballname}" ${thisprod} || \
    { echo 1>&2 <<EOF
ERROR in $thisCom: unable to create "${MRB_BUILDDIR}/${tarballname}"
EOF
      exit 1; }
  printf "%-20s %-15s %-60s\n" "${thisprod}" "${thisver}" "${tarballname}" >> "${MRB_BUILDDIR}/${manifest}"
done
cd "${MRB_BUILDDIR}"
