#!/usr/bin/env bash

# Usage function
function usage() {
    echo "Usage: $(basename $0) <path>"
    echo "   get the actual path to the supplied directory"
}

input_dir=${1}

if [ -z ${input_dir} ]
then
   echo "ERROR: input directory not specified"
   usage
   exit 1
fi

if [ ! -d ${input_dir} ]
then
   echo "ERROR: ${input_dir} is not a directory"
   usage
   exit 1
fi

( cd / ; /bin/pwd -P ) >/dev/null 2>&1
if (( $? == 0 )); then
  pwd_P_arg="-P"
fi
output_dir=`cd ${input_dir} && /bin/pwd ${pwd_P_arg}`
echo ${output_dir}


exit 0
