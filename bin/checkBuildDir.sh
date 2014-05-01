#!/usr/bin/env bash

# Check if we are sitting in the right build area
if pwd | egrep -q '/build[^/]*$';
then
  pwda=`pwd`
  reldir=`${MRB_DIR}/bin/findDir.sh ${pwda}`
  if [ ${reldir} != ${MRB_BUILDDIR} ];
  then
     ##echo "NOTICE: Changing \$MRB_BUILDDIR to ${reldir}"
     export MRB_BUILDDIR=${reldir}
  fi
fi

echo  ${MRB_BUILDDIR}

exit 0
