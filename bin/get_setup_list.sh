#!/usr/bin/env bash

# Called by setup_local_products.
# Creates a temporary script to be sourced
# and writes the name of the temporary script
# to the standard output.

source `${UPS_DIR}/bin/ups setup ${SETUP_UPS}`
tmpfl=/tmp/`basename $MRB_INSTALL`_setup_$$$$
rm -f "${tmpfl}"
echo > "${tmpfl}"
echo "## checking $MRB_INSTALL for products" >> "${tmpfl}"
echo "source \`${UPS_DIR}/bin/ups setup ${SETUP_UPS}\`" >> "${tmpfl}"

ups list -aK+ -z "${MRB_INSTALL}" | while read line
do
  ##echo "got line: $line"
  words=($(echo $line | tr ' ' "\n"))
  ##echo "split into ${#words[@]} pieces"
  product=$(echo ${words[0]} | tr '"' ' ')
  version=$(echo ${words[1]} | tr '"' ' ')
  quals=$(echo ${words[3]} | tr '"' ' ')
  product_uc=$(echo ${product} | LANG=C tr '[a-z]' '[A-z]')
  product_setup=$(printenv | grep SETUP_${product_uc} | cut -f2 -d'=')
  if [ -z "${product_setup}" ]
  then
     echo "# $product is not setup" >> "${tmpfl}"
  else
     echo "unsetup -j $product" >> "${tmpfl}"
  fi
  if [ -z $quals ]
  then
      cmd="setup -B $product $version"
  else
      pq=+`echo ${quals} | sed -e 's/:/:+/g'`
      cmd="setup -B $product $version -q $pq"
  fi
  echo "$cmd -z ${MRB_INSTALL}:${PRODUCTS}" >> "${tmpfl}"
done

echo "${tmpfl}"

exit 0
