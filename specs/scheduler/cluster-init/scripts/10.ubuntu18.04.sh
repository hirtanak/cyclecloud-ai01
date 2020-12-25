#!/bin/bash
# Copyright (c) 2020 Hiroshi Tanaka, hirtanak@gmail.com @hirtanak
set -exuv

echo "starting 10.ubuntu18.04.sh"

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


if [[ ${PLATFORM} == "ubuntu" ]] && [[ ${PLATFORM_VERSION} == "18.04" ]]; then 
   echo "pass to the following steps"
   else 
   echo "end of this script" && exit 0  
fi

# fix the shell issue
declare i && i=1
declare line 
declare CNT && CNT=0
ls /home | awk '{ print $1 }' > ${HOMEDIR}/shell
awk -F ',' '{print $1,$2}' ${HOMEDIR}/shell 
sed '/^$/d' ${HOMEDIR}/shell
chown ${CUSER}:${CUSER} ${HOMEDIR}/shell

CNT=$(wc -l ${HOMEDIR}/shell | awk '{ print $1}')
while [[ $i -le $CNT ]]; do
   echo "cheking $i user"
   cat ${HOMEDIR}/shell
   line=$(sed -n $i\P ${HOMEDIR}/shell)
   usermod ${line} -s /bin/bash
   let i++
done

# set up requirement: jupyterhub
if [[ ${JUPYTERHUB_INSTALL} == "True" ]] || [[ ${JUPYTERHUB_INSTALL} == "true" ]]; then
    apt-get install -y npm
    npm install -g configurable-http-proxy
fi

# annaconda install
#set +u
if [[ ! -f ${HOMEDIR}/anaconda.sh ]]; then 
   wget -nv https://repo.anaconda.com/archive/Anaconda3-2020.02-Linux-x86_64.sh -O ${HOMEDIR}/anaconda.sh
   chown ${CUSER}:${CUSER} ${HOMEDIR}/anaconda.sh
   chmod +x ${HOMEDIR}/anaconda.sh
   sudo -u ${CUSER} bash ${HOMEDIR}/anaconda.sh -b -p ${HOMEDIR}/anaconda
   echo "end anaconda installation"
fi

# env settingsg
set +eu
CMD1=$(grep codna ${HOMEDIR}/.bashrc)
if [[ -z "${CMD1}" ]]; then
   (echo "source ${HOMEDIR}/anaconda/etc/profile.d/conda.sh") >> ${HOMEDIR}/.bashrc
fi
chmod +x ${HOMEDIR}/anaconda/etc/profile.d/conda.sh
set -eu

# anaconda setting
set +u
ANACONDAENVNAME=$(jetpack config ANACONDAENVNAME)
ANACONDAPYTHON_VERSION=$(jetpack config ANACONDAPYTHON_VERSION)
ANACONDAPACKAGE=$(jetpack config ANACONDAPACKAGE)

CMD2=$(${HOMEDIR}/anaconda/bin/conda info -e | grep "\(${ANACONDAENVNAME}\)") | exit 0

if [[ ${CMD2} == "base" ]]; then
    :  
else 
   echo "else"
   # conda create -n yourenvname python=x.x anaconda
   mkdir -p /root/.conda
   chown -R ${CUSER}:${CUSER} /root/
   # set up requirement: jupyterhub
   if [[ ${JUPYTERHUB_INSTALL} == "True" ]] || [[ ${JUPYTERHUB_INSTALL} == "true" ]]; then
       ${HOMEDIR}/anaconda/bin/conda create -n ${ANACONDAENVNAME} python=${ANACONDAPYTHON_VERSION} jupyterlab ${ANACONDAPACKAGE}
	# ${HOMEDIR}/anaconda/bin/conda create -n ${ANACONDAENVNAME} python=${ANACONDAPYTHON_VERSION} jupyterlab jupyterhub nodejs ${ANACONDAPACKAGE}
#       ${HOMEDIR}/anaconda/bin/conda activate ${ANACONDAENVNAME} 
#       ${HOMEDIR}/anaconda/bin/conda install -c conda-forge sudospawner
#        ${HOMEDIR}/anaconda/bin/conda install -n ${ANACONDAENVNAME} -c conda-forge sudospawner
#	${HOMEDIR}/anaconda/bin/conda update -n ${ANACONDAENVNAME} -c conda-forge sudospawner
   else
       # jupyterlabのみのインストール
       ${HOMEDIR}/anaconda/bin/conda create -n ${ANACONDAENVNAME} python=${ANACONDAPYTHON_VERSION} jupyterlab ${ANACONDAPACKAGE}
   fi
fi
set -u


popd
rm -rf $tmpdir

echo "end of 10.ubuntu18.04.sh"
