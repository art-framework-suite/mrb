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
Usage: $fullCom 
  Make distribution tarballs for each product installed by this build
EOF
}

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
make DESTDIR=${temp_install_dir} install $*

# full path to products
mrb_install_path=`${MRB_DIR}/bin/findDir.sh ${MRB_INSTALL}`
temp_install_path=${temp_install_dir}/${mrb_install_path}

product_list=`ls ${temp_install_path}`
echo $product_list

thisos=`get-directory-name os`

for thisprod in $product_list
do
  thisver=`ls ${temp_install_path}/${thisprod} | grep -v version`
  thisdotver=`echo ${thisver} | sed -e 's/_/./g' | sed -e 's/^v//'`
  flvrdir=`ls -d ${temp_install_path}/${thisprod}/${thisver}/${thisos}*`
  thisflvr=$(basename ${flvrdir})
  #echo ${thisprod} ${thisver} ${thisflvr}
  tarflvr=`echo ${thisflvr} | sed -e 's/\./-/g'`
  tarballname=${thisprod}-${thisdotver}-${tarflvr}.tar.bz2
  echo "making ${tarballname}"
  cd ${temp_install_path}; tar cjf ${MRB_BUILDDIR}/${tarballname} ${thisprod}
done
cd ${MRB_BUILDDIR}

# cleanup
rm -rf ${temp_install_dir}

exit 0
