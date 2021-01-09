#!/bin/bash
# Copyright (c) 2020 Hiroshi Tanaka, hirtanak@gmail.com @hirtanak
set -exuv

SW=jupyterhub-user
echo "starting 20.ubuntu18.04-${SW}.sh"

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
# jupyterhub ユーザ作成
JUPYTER_ADMIN=jupyterhub
HOMEDIR=/shared/home/${JUPYTER_ADMIN}
CYCLECLOUD_SPEC_PATH=/mnt/cluster-init/ai01/scheduler
# get palrform
PLATFORM=$(jetpack config platform)
PLATFORM_VERSION=$(jetpack config platform_version)
# jupyterlab 設定
JUPYTERHUB_INSTALL=$(jetpack config JUPYTERHUB_INSTALL)
JUPYTERHUB_USER_PASS=$(jetpack config JUPYTERHUB_USER_PASS)
# anaconda パラメータ
ANACONDAENVNAME=$(jetpack config ANACONDAENVNAME)
ANACONDAPYTHON_VERSION=$(jetpack config ANACONDAPYTHON_VERSION)
ANACONDAPACKAGE=$(jetpack config ANACONDAPACKAGE)

# jupyterhub ユーザ作成
userdel ${JUPYTER_ADMIN} | exit 0

groupadd ${JUPYTER_ADMIN} -g 19000 | exit 0
useradd -m ${JUPYTER_ADMIN} -g ${JUPYTER_ADMIN} -u 19000 --password ${JUPYTERHUB_USER_PASS} -s /bin/bash | exit 0

# 権限・グループ設定
usermod -aG ${SCRIPTUSER} ${JUPYTER_ADMIN} | exit 0
usermod -aG sudo ${JUPYTER_ADMIN} | exit 0
#usermod -aG root ${JUPYTER_ADMIN} | exit 0
