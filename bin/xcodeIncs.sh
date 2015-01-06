#!/bin/bash
#
# Add referneces to headers to an Xcode project
#
# You must have everything set up already first (e.g. do ". mrb s")
#
# You should add ${MRB_SOURCE} to the "Header Search Paths" in the project first.
#


function usage() {
cat 1>&2 << EOF
Usage: xcodeIncs.sh [options] /path/to/Xcode/project

Insert references to headers into an Xcode project.

You must have everything set up already (e.g. do ". mrb s").

You must have already added \${MRB_SOURCE} to the "Header Search Paths" in the Xcode project.

Paths to art, geant4, cetlib, messagefacility, fhiclcpp, clhep, root, and gm2* are included.
If you want even more (everything with an INC in the environment variable name), do "-a", but note that
doing so could make Xcode very slow.

The argument is the path to the Xcode project. The path should end in the project name (no final slash).

Options (not recommended unless you know what you are doing):
-a       Search all include paths (may make Xcode slow)

EOF
}

# ---- Main ----

# Determine command options (just -h for help)

doall='--none--'

while getopts ":ha" OPTION
do
case $OPTION in
h   ) usage ; exit 0 ;;
a   ) doall=true;;
*   ) echo "ERROR: Unknown option" ; usage ; exit 1 ;;
esac
done

# Get the path to the project
shift $((OPTIND - 1))
if [ $# -lt 1 ]; then
echo "ERROR: No path to xcode project"
usage
exit 1
fi

# Capture the product name
xcodeprojpath=$1
xcodeproj=$(basename $xcodeprojpath)
projFile=${xcodeprojpath}/${xcodeproj}.xcodeproj/project.pbxproj

# Does the project file exist?
if [ ! -r "$projFile" ]; then
  echo "ERROR: $projFile does not exist"
  exit 2
fi

# Do the search and replace
if [ "$doall" == "true" ]; then
  r=$(env | grep INC | sort | awk 'BEGIN { FS="="; ORS=" "} ; { print "\"${"$1"}\"," } ')
else
  r=$(env | grep INC | egrep 'ART|G4|CET|MESSAGE|FHICL|CLHEP|GM2[^_]|ROOT_' | grep -v DIR | sort | awk 'BEGIN { FS="="; ORS=" "} ; { print "\"${"$1"}\"," } ')
fi

echo "Adding $r"
sed -i '.bak' "s/\"\${MRB_SOURCE}\",/\"\${MRB_SOURCE}\",$r/" $projFile

echo "Updated $projFile"
