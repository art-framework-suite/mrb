#!/usr/bin/env bash

# Setup a development environment by calling a @setup_for_development@ script

# Usage: 
#   <pre>
#   source mrb setEnv source_area src_options <br />
#   e.g. source mrb setEnv ~/mysrcs/srcs -d e1
#  </pre>

#  The source_area must point to a directory that contains a setEnv
#  file or has ups/setup_for_development 

# Function to show command usage
function usage() {

cat 1>&2 << EOF
Usage: source mrb setEnv [source_area] options

e.g.   source mrb setEnv $MRB_SOURCE 
e.g.   source mrb setEnv   # Equivalent to above

The source_area must point to a directory that contains a setEnv
file or has ups/setup_for_development 

If you leave source_area blank, $MRB_SOURCE is assumed.

EOF
}

srcDir=$MRB_SOURCE

if [ $# -gt 0 ]; then

  if [ "$1" == "-H" ];then
    usage
    exit 0  # Must not be sourced
  fi

  if [ "$1" == "-h" ]; then
    usage
    return 
  fi
  
  # Is the first argument a directory?
  if [ -d $1 ]; then
    srcDir=$1 ; shift
  fi

fi

# search qualifiers
qlist=`echo ${MRB_QUALS} | sed -e 's/:/ /g' | tr " " "\n"| sort |tr "\n" " "`
myq=""
for qual in ${qlist}
do
  if [ ${qual} == "debug" ]
  then
    dop="-d"
  elif [ ${qual} == "opt" ]
  then
    dop="-o"
  elif [ ${qual} == "prof" ]
  then
    dop="-p"
  else
    myq=${qual}:${myq}
  fi
done
quals=`echo ${myq} | sed -e 's/::/:/g' | sed -e 's/:$//'`

# Check if we are sitting in the right build area
if pwd | egrep -q '/build[^/]*$';
then
  if [ $PWD != ${MRB_BUILDDIR} ];
  then
     echo "NOTICE: Changing \$MRB_BUILDDIR to $PWD"
     export MRB_BUILDDIR=$PWD
  fi
fi

# MRB_BUILDDIR must point to a directory called build
if echo ${MRB_BUILDDIR} | egrep -q '/build[^/]*$';
then

   # Directory must exist
   if [ -d "$MRB_BUILDDIR" ];
   then 

      # Source @setup_for_development@ either in this directory or in ups
      if [ -r ${srcDir}/setEnv ]; then
        source ${srcDir}/setEnv ${dop} ${quals}
      else
        echo "Cannot find ${srcDir}/setEnv"
        return
      fi

   else
      echo "ERROR - Build directory $MRB_BUILDDIR does not exist"
      return

   fi
   
else
    echo "ERROR: \$MRB_BUILDDIR must point to a directory that starts with build"
fi

return
