#!/bin/bash
# Copyright (c) 2020 Hiroshi Tanaka, hirtanak@gmail.com @hirtanak
set -exuv

SW=vscode
echo "starting 30.ubuntu18.04-${SW}.sh"

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


# check platform
if [[ ${PLATFORM} == "ubuntu" ]] && [[ ${PLATFORM_VERSION} == "18.04" ]]; then 
   echo "pass to the following steps"
   else 
   echo "end of this script" && exit 0  
fi

# check start this script
if [[ ${DESKTOP_INSTALL} == "False" ]] || [[ ${DESKTOP_INSTALL} == "false" ]]; then
   echo "end of this script" && exit 0
fi

# desktp install
apt-get install -y ubuntu-desktop
systemctl set-default graphical.target

# xrdp set up
apt-get -y install xrdp
systemctl enable xrdp
systemctl start xrdp
systemctl status xrdp

(echo "xfce4-session") > ${HOMEDIR}/.xsession

service xrdp restart


popd
rm -rf $tmpdir

echo "end of 30.ubuntu18.04-${SW}.sh"
