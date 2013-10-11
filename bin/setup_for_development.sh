#!/usr/bin/env bash

# Setup a development environment by calling a @setup_for_development@ script

# Usage: 
#   <pre>
#   source mrb setup_for_development src_area src_options <br />
#   e.g. source mrb setup_for_development ~/mysrcs/srcs -d e1
#  </pre>

#  The src_area must point to a directory that contains a setup_for_development
#  file or has ups/setup_for_development 

# Function to show command usage
function usage() {

cat 1>&2 << EOF
Usage: source mrb setup_for_development [source_area] options

e.g.   source mrb setup_for_development $SRCS 
e.g.   source mrb setup_for_development   # Equivalent to above

The src_area must point to a directory that contains a setup_for_development
file or has ups/setup_for_development 

If you leave src_area blank, $SRCS is assumed. 

If you are compiling products with no flavor, use -n


EOF
}

srcDir=$SRCS

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
 
# We must be sitting in a build area
if pwd | egrep -q '/build[^/]*$';
then

    # Source @setup_for_development@ either in this directory or in ups
    if [ -r ${srcDir}/setup_for_development ]; then
      source ${srcDir}/setup_for_development $*
    elif [ -r ${srcDir}/ups/setup_for_development ]; then
      source ${srcDir}/ups/setup_for_development $*
    else
      echo 'Cannot locate a setup_for_development script'
      return
    fi
else
    echo 'Your current directory must be a build area (e.g. starts with build)'
fi

return
