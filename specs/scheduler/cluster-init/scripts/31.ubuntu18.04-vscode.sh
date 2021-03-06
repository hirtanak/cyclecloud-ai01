#!/bin/bash
# Copyright (c) 2020 Hiroshi Tanaka, hirtanak@gmail.com @hirtanak
set -exuv

SW=vscode
echo "starting 31.ubuntu18.04-${SW}.sh"

# adapt multi user environment
SCRIPTUSER=$(jetpack config SCRIPTUSER)
if [[ -z ${SCRIPTUSER} ]] || [[ ${SCRIPTUSER} = "None" ]]; then
   CUSER=$(grep "Added user" /opt/cycle/jetpack/logs/jetpackd.log | awk '{print $6}')
   CUSER=${CUSER//\'/}
   CUSER=${CUSER//\`/}
   # After CycleCloud 7.9 and later
   if [[ -z $CUSER ]]; then
      CUSER=$(grep "Added user" /opt/cycle/jetpack/logs/initialize.log | awk '{print $6}' | head -1)
      CUSER=${CUSER//\`/}
      echo ${CUSER} > /mnt/exports/CUSER
   fi
else
   echo ${SCRIPTUSER} > /shared/SCRIPTUSER
   CUSER=${SCRIPTUSER}
   echo ${SCRIPTUSER} > /shared/CUSER
fi
HOMEDIR=/shared/home/${CUSER}
CYCLECLOUD_SPEC_PATH=/mnt/cluster-init/ai01/scheduler
# get palrform
PLATFORM=$(jetpack config platform)
PLATFORM_VERSION=$(jetpack config platform_version)
DESKTOP_INSTALL=$(jetpack config DESKTOP_INSTALL)

# Create tempdir
tmpdir=$(mktemp -d)
pushd $tmpdir


if [[ ${DESKTOP_INSTALL} == "False" ]] || [[ ${DESKTOP_INSTALL} == "false" ]]; then 
   echo "end of this script" && exit 0  
fi

if [[ ${PLATFORM} == "ubuntu" ]] && [[ ${PLATFORM_VERSION} == "18.04" ]]; then
   echo "pass to the following steps"
   else
   echo "end of this script" && exit 0
fi

if [[ ! -f /snap/bin/code ]]; then
    # install vscode
    snap install --classic code
    # check snap package
    snap list
fi

set +u
CMD=$(grep "snap/bin/code" ${HOMEDIR}/.barcsh) | exit 0
if [[ ! -z ${CMD} ]]; then
    (echo "/snap/bin/code") >> .bashrc
fi
set -u


popd
rm -rf $tmpdir

echo "end of 31.ubuntu18.04-${SW}.sh"
