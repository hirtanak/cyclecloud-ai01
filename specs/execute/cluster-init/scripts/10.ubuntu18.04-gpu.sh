#!/bin/bash
# Copyright (c) 2020 Hiroshi Tanaka, hirtanak@gmail.com @hirtanak
set -exuv

echo "starting 10.ubuntu18.04-gpu.sh"

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
JUPYTERHUB_INSTALL=$(jetpack config JUPYTERHUB_INSTALL)

# Create tempdir
tmpdir=$(mktemp -d)
pushd $tmpdir

set +u
CMD=$(lspci | grep -i NVIDIA) | exit 0
if [[ -z ${CMD} ]]; then 
    exit 0
fi

if [[ ${PLATFORM} == "ubuntu" ]] && [[ ${PLATFORM_VERSION} == "18.04" ]]; then
    # Driverチェック
    CMD2=$(cat /proc/driver/nvidia/version | head -1 | awk '{print $3}') | exit 0
    if [[ ! -z ${CMD2} ]]; then        
        echo "install NVIDIA driver"
        wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/cuda-ubuntu1804.pin -O ${HOMEDIR}
        mv cuda-ubuntu1804.pin /etc/apt/preferences.d/cuda-repository-pin-600
        apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/7fa2af80.pub
        add-apt-repository "deb https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/ /"
        apt-get update
        apt-get -y install cuda	
#	reboot
    fi
    nvidia-smi
else
    echo "NVIDIA Driver has already indstalled"
fi
