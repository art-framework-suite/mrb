#!/usr/bin/env bash

# use DESTDIR to define a temporary install directory
# use temporary install directory structure to determine tarball names

# Determine the name of this command
thisComFull=$(basename $0)
thisCom=${thisComFull%.*}

# Merge it with the "umbrella" command (like mrb)
fullCom="${mrb_command} $thisCom"

# Function to show command usage
function usage() 
{
  cat 1>&2 << EOF
Usage: $fullCom [options] [-- options for make]
  Make distribution tarballs for each product installed by this build
  Options:
     -n <distribution_name> = the name for the manifest (e.g., uboone, lbne, ...)
         If unspecified, this defaults to MRB_PROJECT
     -v <version> = the version for the manifest (vx_y_z format)
         If unspecified, this defaults to MRB_PROJECT_VERSION
     -j <ncores> = pass along the -j flag to make for backwards compatibility
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

if [ -z ${MRB_BUILDDIR} ]
then
  echo "ERROR in ${thisCom}: MRB_BUILDDIR is not defined."
  echo '       source the appropriate localProductsXXX/setup'
  exit 1
fi

# define the temporary install directory and make sure it is empty
temp_install_dir=${MRB_BUILDDIR}/tempinstall
rm -rf ${temp_install_dir}

# run make install
make DESTDIR=${temp_install_dir} install ${jcores} $*

# full path to products
mrb_install_path=`${MRB_DIR}/bin/findDir.sh ${MRB_INSTALL}`
temp_install_path=${temp_install_dir}/${mrb_install_path}

product_list=`ls ${temp_install_path}`
echo $product_list

thisos=`get-directory-name os`

myflvr=`ups flavor`
myOS=`uname -s`
if [ ${myOS} = "Darwin" ]
then
    myflvr=`ups flavor -2`
fi
myqualdir=`echo ${MRB_QUALS} | sed s'/:/-/g'`
mydotver=`echo ${distribution_version} |  sed -e 's/_/./g' | sed -e 's/^v//'`

manifest=${distribution_name}-${mydotver}-${myflvr}-${myqualdir}_MANIFEST.txt

echo "create manifest ${manifest}"
rm -f ${manifest}
touch ${manifest}
for thisprod in $product_list
do
  thisver=`ls ${temp_install_path}/${thisprod} | grep -v version`
  thisdotver=`echo ${thisver} | sed -e 's/_/./g' | sed -e 's/^v//'`
  if [ -e ${temp_install_path}/${thisprod}/${thisver}/${thisos}* ]
  then
    flvrdir=`ls -d ${temp_install_path}/${thisprod}/${thisver}/${thisos}*`
    thisflvr=$(basename ${flvrdir})
    #echo ${thisprod} ${thisver} ${thisflvr}
    tarflvr=`echo ${thisflvr} | sed -e 's/\./-/g'`
    tarballname=${thisprod}-${thisdotver}-${tarflvr}.tar.bz2
  else
    tarballname=${thisprod}-${thisdotver}-noarch.tar.bz2
  fi
  echo "making ${tarballname}"
  cd ${temp_install_path}; tar cjf ${MRB_BUILDDIR}/${tarballname} ${thisprod}
  printf "%-20s %-15s %-60s\n" "${thisprod}" "${thisver}" "${tarballname}" >> "${MRB_BUILDDIR}/${manifest}"
done
cd ${MRB_BUILDDIR}

# cleanup
rm -rf ${temp_install_dir}

exit 0
