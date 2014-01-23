#!/bin/bash

# make a mrb ups product


usage()
{
   echo "USAGE: `basename ${0}` <product_dir>"
   echo "       `basename ${0}` installs mrb as a relocatable ups product"
}

get_my_dir() 
{
    ( cd / ; /bin/pwd -P ) >/dev/null 2>&1
    if (( $? == 0 )); then
      pwd_P_arg="-P"
    fi
    reldir=`dirname ${0}`
    mydir=`cd ${reldir} && /bin/pwd ${pwd_P_arg}`
}


product_dir=${1}

if [ -z ${product_dir} ]
then
   echo "ERROR: please specify the product directory"
   usage
   exit 1
fi

package=mrb
pkgver=v0_05_05
pkgdotver=`echo ${pkgver} | sed -e 's/_/./g' | sed -e 's/^v//'`

get_my_dir

pkgdir=${product_dir}/${package}
if [ ! -d ${pkgdir} ]
then
  mkdir -p ${pkgdir} || exit 2;
fi

# cleanup the old directory if necessary
if [ -d ${pkgdir}/${pkgver} ]
then
   set -x
   rm -rf ${pkgdir}/${pkgver} ${pkgdir}/${pkgver}.version ${pkgdir}/current.chain
   set +x
fi

set -x
# pull the tagged release from git
git archive --prefix=${pkgver}/ \
            --remote ssh://p-${package}@cdcvs.fnal.gov/cvs/projects/${package} \
            -o ${mydir}/${package}-${pkgver}.tar ${pkgver}
cd ${pkgdir}
tar xf ${mydir}/${package}-${pkgver}.tar
set +x

# we will use ups declare
if [ -z ${UPS_DIR} ]
then
   echo "ERROR: please setup ups"
   exit 1
fi
source `${UPS_DIR}/bin/ups setup ${SETUP_UPS}`

ups declare -c ${package} ${pkgver} -r ${package}/${pkgver} -0 -m ${package}.table  -z ${product_dir}

ups list -aK+ ${package} ${pkgver}   -z ${product_dir}

# now make the tar ball
set -x
cd ${product_dir}
tar cjf ${package}-${pkgdotver}-noarch.tar.bz2 ${package}/${pkgver} ${package}/${pkgver}.version ${package}/current.chain
set +x

exit 0

