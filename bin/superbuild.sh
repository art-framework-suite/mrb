#!/usr/bin/env bash

# Perform a superbuild!

# Determine this command name
thisComFull=$(basename $0)
thisCom=${thisComFull%.*}
fullCom="${mrb_command} $thisCom"

# Usage function
function usage() {
  cat 1>&2 << EOF
Usage: $fullCom [options] <buildFacilityPassword>

Perform a superbuild on Fermilab build facility.

Default operation is for you to commit and push all code in srcs. Superbuild will then
download those branches from git and will build.

Normally, you would give no options (you do have to give the password)

Options (not recommended unless you know what you are doing):
  -j     = Specify jenkins project (default is gm2_superbuild2)
  -v     = gm2 version (e.g. v5_00_00)  [Default is to figure this out from your dev area]
  -q     = gm2 qualifiers (e.g. e6:prof) [Default is to figure this out from your dev area]
  -s     = srcs list:  prod1:branch1:prod2:branch2:... [Default is to figure this out from your dev area]
  -P     = Tar up local products and ship it to the build facility to build against
  -b     = Get a products tar file from the build master (e.g. from a previous build)
                   E.g. gm2-superbuild2-copyout/19/artifact/superbuild_19.tgz
  -R     = Build for a release (**not** for general use)

EOF
}

determineSrcs() {
  cd $MRB_SOURCE
  srcList=$(grep '^ADD' .cmake_add_subdir | cut -d'(' -f 2 | cut -d')' -f 1)

  for aSrc in $srcList; do
    cd $aSrc

    # Is everything up to date?
    gitstatus1=$(git status -s | wc -l)
    if [ $gitstatus1 -ne 0 ]; then
      echo "Cannot build; $aSrc is not committed to git (git status -s returns something)"
      exit 2
    fi

    gitstatus2=$(git status | grep 'up-to-date' | wc -l)
    if [ $gitstatus2 -eq 0 ]; then
      echo "Cannot build; $aSrc is not up to date (git status does not say up-to-date)"
      exit 3
    fi

    if [ "$srcs" == '--none--' ]; then
      srcs=$aSrc
    else
      srcs=$srcs:$aSrc
    fi

    branch=$(git rev-parse --abbrev-ref HEAD)
    srcs=$srcs:$branch

    cd ..

  done

}
# ---- Main ----

# Determine command options (just -h for help)

gm2ver='--none--'
gm2qual='--none--'
srcs='--none--'
jenkinsProject='gm2-superbuild2'
doSrcsTar=false
doProdTar=false
doRelease=false
prodFromBM='--none--'

while getopts ":hv:q:s:b:j:UPR" OPTION
do
    case $OPTION in
        h   ) usage ; exit 0 ;;
        j   ) jenkinsProject=$OPTARG;;
        v   ) gm2ver=$OPTARG;;
        q   ) gm2qual=$OPTARG;;
        s   ) srcs=$OPTARG;;
        b   ) prodFromBM=$OPTARG;;
        U   ) doSrcsTar=true;;
        P   ) doProdTar=true;;
        R   ) doRelease=true;;
        *   ) echo "ERROR: Unknown option" ; usage ; exit 1 ;;
    esac
done

# Get the token
shift $((OPTIND - 1))
if [ $# -lt 1 ]; then
    echo "ERROR: No build facility password given"
    usage
    exit 1
fi

# Capture the product name
token=$1

# Do some consistency checks
# Can't do -s and -U
if [ "$srcs" != '--none--' ] && [ "$doSrcsTar" == "true" ]; then
  echo "Cannot specify both -s and -U"
  exit 2
fi

# Can't do -P and -b
if [ "$prodFromBM" != '--none--' ] && [ "$doProdTar" == "true" ]; then
echo "Cannot specify both -b and -P"
exit 2
fi

# Determine the gm2 version and qualifier
if [ "$gm2ver" == "--none--" ]; then
  gm2ver=$MRB_PROJECT_VERSION
fi

if [ "$gm2qual" == "--none--" ]; then
  gm2qual=$MRB_QUALS
fi

# Determine the sources or tar them up
# Do we want a tar file?
if [ "$doSrcsTar" == "true" ]; then
  cd $MRB_SOURCE
  srcList=$(grep '^ADD' .cmake_add_subdir | cut -d'(' -f 2 | cut -d')' -f 1 | paste -sd " " -)
  echo "Will tar sources for $srcList"
  tar cvzf $MRB_TOP/superbuild_srcs.tgz --exclude=.git $srcList
  srcs=""
else
  if [ "$srcs" == "--none--" ]; then
    determineSrcs
  fi
  echo "Will build sources: $srcs"
fi

# Tar up the products if necessary
if [ "$doProdTar" == "true" ]; then
  cd $MRB_INSTALL
  echo 'Tarring products'
  tar cvzf $MRB_TOP/superbuild_prod.tgz * .upsfiles
fi

# Blank out prodFromBM if necessary
if [ "$prodFromBM" == "--none--" ]; then
  prodFromBM=""
fi

# Create the curl string
jsonstring="{\"parameter\": [ {\"name\":\"GM2VERSION\", \"value\":\"$gm2ver\"},
                              {\"name\":\"GM2QUALS\", \"value\":\"$gm2qual\"},
                              {\"name\":\"SRCSTOBUILD\", \"value\":\"$srcs\"},
                              {\"name\":\"WHO\", \"value\":\"$USER\"},
                              {\"name\":\"FROM\", \"value\":\"$HOSTNAME\"},
                              {\"name\":\"PRODUCTSFROMBUILDMASTER\", \"value\":\"$prodFromBM\"},
                              {\"name\":\"FORRELEASE\", \"value\":\"$doRelease\"} "
filestring="--none--"

if [ "$doSrcsTar" == "true" ]; then
  jsonstring="${jsonstring}, {\"name\":\"SRCSTGZ\", \"file\":\"file0\"} "
  filestring="--form file0=@$MRB_TOP/superbuild_srcs.tgz "
fi

if [ "$doProdTar" == "true" ]; then
  jsonstring="${jsonstring}, {\"name\":\"PRODUCTSTGZ\", \"file\":\"file1\"} "
  filestring="--form file1=@$MRB_TOP/superbuild_prod.tgz "
fi

jsonstring="${jsonstring} ]}"

com="curl -X POST https://buildmaster.fnal.gov/job/${jenkinsProject}/build?token=$token
          --form json='${jsonstring}' "


if [ "$filestring" != "--none--" ]; then
  com="${com} ${filestring}"
  echo ' !! Uploading tar files could take awhile !! '
fi

echo $com > /tmp/doSuperbuildCurl.sh

# Send it
echo "Submitting..."
echo "$com"
bash /tmp/doSuperbuildCurl.sh
rm -f /tmp/doSuperbuildCurl.sh
echo '-----------------'
echo 'If there was no output, then your build is queued/running.'
echo "See https://buildmaster.fnal.gov/job/${jenkinsProject} for your job status."
echo "See https://buildmaster.fnal.gov/job/${jenkinsProject}-copyout (perhaps) for job artifacts."

exit 0
