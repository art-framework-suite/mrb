#!/usr/bin/env bash

# Setup all products installed in localProducts...

# Usage: 
#   <pre>
#   source mrb setEnv source_area src_options <br />
#   e.g. source mrb setEnv ~/mysrcs/srcs -d e1
#  </pre>

#  The source_area must point to a directory that contains a setEnv file

# Function to show command usage
function usage() {

cat 1>&2 << EOF
Usage: source mrb setup_local_products

EOF
  [ $isSourced ] && return || exit 1
}

# setEnv must be sourced in order to affect your environment
# This is not necessary for the other mrb commands.
# Did the user source this script?
isSourced=""
[[ ${BASH_SOURCE[0]} != "${0}" ]] && isSourced="yes"


localP=$MRB_INSTALL

if [ $# -gt 0 ]; then

  if [ "$1" == "-H" ];then
    usage
  fi

  if [ "$1" == "-h" ]; then
    usage
  fi

fi

if [ "$isSourced" != "yes" ]
then 
  echo 'You must source to run setup_local_products'
  echo ' '
  usage
  exit 5 
fi

# Make sure we have ups
if [ -z ${UPS_DIR} ]
then
   echo "ERROR: please setup ups"
   exit 1
fi
source `${UPS_DIR}/bin/ups setup ${SETUP_UPS}`
 
echo "checking $localP for products"

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
      cmd="setup $product  $version"
  else
      cmd="setup $product  $version -q $quals"
  fi
  echo $cmd
  source `${UPS_DIR}/bin/ups $cmd -z $localP:${PRODUCTS}`
done

return
