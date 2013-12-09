#!/usr/bin/env bash

# called by setup_local_products
# creates a temporary script to be sourced

#  The source_area must point to a directory that contains a setEnv file

# Function to show command usage
function usage() {

cat 1>&2 << EOF
Usage: source mrb get_setup_list

EOF
exit 1
}

localP=$MRB_INSTALL

if [ $# -gt 0 ]; then

  if [ "$1" == "-H" ];then
    usage
  fi

  if [ "$1" == "-h" ]; then
    usage
  fi

fi

# Make sure we have ups
if [ -z ${UPS_DIR} ]
then
   echo "ERROR: please setup ups"
   exit 1
fi
source `${UPS_DIR}/bin/ups setup ${SETUP_UPS}`

tmpfl=/tmp/`basename $localP`_setup_$$$$
rm -f $tmpfl
echo > $tmpfl
echo "## checking $localP for products" >> $tmpfl
echo "source \`${UPS_DIR}/bin/ups setup ${SETUP_UPS}\`" >> $tmpfl

ups list -aK+ -z $localP | while read line
do
  ##echo "got line: $line"
  words=($(echo $line | tr " " "\n"))
  ##echo "split into ${#words[@]} pieces"
  product=$(echo ${words[0]} | tr "\"" " ")
  version=$(echo ${words[1]} | tr "\"" " ")
  quals=$(echo ${words[3]} | tr "\"" " ")
  ##if [ ${words[3]} = \"\" ]
  if [ -z $quals ]
  then
      cmd="setup -B $product  $version"
  else
      pq=+`echo ${quals} | sed -e 's/:/:+/g'`
      cmd="setup -B $product  $version -q $pq"
  fi
  echo "$cmd -z $localP:${PRODUCTS}" >> $tmpfl
done

echo $tmpfl

exit 0

