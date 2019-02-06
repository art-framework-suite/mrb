#!/usr/bin/env bash

# designed for use on macOS
# There should be no output if SIP is disabled.

myOS=`uname -s`
if [ ${myOS} = "Darwin" ]; then
   #echo "INFO: making sure SIP is disabled"
   #csrutil status
   mystat=`csrutil status | cut -f2 -d":"`
   isok=`csrutil status | grep disabled | wc -l`
   #echo "INFO: SIP is ${mystat}"
   if [ ${isok} = "0" ]; then
      echo "ERROR   ERROR   ERROR   ERROR   ERROR   ERROR   ERROR   ERROR"
      echo "ERROR: SIP is ${mystat} on this machine"
      echo "ERROR   ERROR   ERROR   ERROR   ERROR   ERROR   ERROR   ERROR"
      exit 1
   else
      exit 0
   fi
fi

exit 0

