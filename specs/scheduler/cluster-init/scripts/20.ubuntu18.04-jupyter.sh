#!/bin/bash
# Copyright (c) 2020 Hiroshi Tanaka, hirtanak@gmail.com @hirtanak
set -exuv

SW=jupyter
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
HOMEDIR=/shared/home/${CUSER}
CYCLECLOUD_SPEC_PATH=/mnt/cluster-init/ai01/scheduler
# get palrform
PLATFORM=$(jetpack config platform)
PLATFORM_VERSION=$(jetpack config platform_version)

# Create tempdir
tmpdir=$(mktemp -d)
pushd $tmpdir


if [[ ${PLATFORM} == "ubuntu" ]] && [[ ${PLATFORM_VERSION} == "18.04" ]]; then 
   echo "pass to the following steps"
   else 
   echo "end of this script" && exit 0  
fi

# anaconda setting
set +u
ANACONDAENVNAME=$(jetpack config ANACONDAENVNAME)
ANACONDAPYTHON_VERSION=$(jetpack config ANACONDAPYTHON_VERSION)
ANACONDAPACKAGE=$(jetpack config ANACONDAPACKAGE)

declare JUPYTERLAB_PASS
declare JUPYTERLABTOKEN
declare JUPUYERSHA1

# セットアップの手順
# conda install -c conda-forge jupyterlab
# jupyter lab --ip=0.0.0.0 --no-browser# 
# ~/anaconda/envs/py37/bin$ jupyter-lab --generate-config
#c.NotebookApp.port = 8888
# #c.NotebookApp.ip = 'localhost'
# c.NotebookApp.mathjax_config = 'TeX-AMS-MML_HTMLorMML-full,Safe'

# set up directry and privillege
mkdir -p ${HOMEDIR}/.jupyter/
chown -R ${CUSER}:${CUSER} ${HOMEDIR}/.jupyter/

# generate jupyter-lab configfile
${HOMEDIR}/anaconda/envs/${ANACONDAENVNAME}/bin/jupyter-lab --generate-config -y

mv /.jupyter/jupyter_notebook_config.py ${HOMEDIR}/.jupyter/jupyter_notebook_config.py | exit 0
chown ${CUSER}:${CUSER} ${HOMEDIR}/.jupyter/jupyter_notebook_config.py | exit 0

# modify jupyter_notebook_config.py: コンフィグの作成
sed -i -e "s/^# c.NotebookApp.port = 8888/c.NotebookApp.port = 443/g" ${HOMEDIR}/.jupyter/jupyter_notebook_config.py
sed -i -e "s/^# c.NotebookApp.ip = 'localhost'/c.NotebookApp.ip = '0.0.0.0'/g" ${HOMEDIR}/.jupyter/jupyter_notebook_config.py
# Other config
sed -i -e "s/^# c.LabApp.open_browser = True/c.LabApp.open_browser = False/g" ${HOMEDIR}/.jupyter/jupyter_notebook_config.py
# 2020/12/22 対応 Token設定と被り
sed -i -e "s/Default: ''/#Default: ''/g" ${HOMEDIR}/.jupyter/jupyter_notebook_config.py

# password set up: パスワードの設定
JUPYTERLAB_PASS=$(jetpack config JUPYTERLAB_PASS)
if [[ ${JUPYTERLAB_PASS} = None ]]; then
   JUPYTERLAB_PASS=password123!
fi
# expect
apt-get install -y expect
cp -rf ${CYCLECLOUD_SPEC_PATH}/files/expect.sh ${HOMEDIR}/expect.sh
chown -R ${CUSER}:${CUSER} ${HOMEDIR}/expect.sh
chmod +x ${HOMEDIR}/expect.sh
set +u
sed -i -e "s/EXPECTPASSWORD/${JUPYTERLAB_PASS}/g" ${HOMEDIR}/expect.sh
sed -i -e "3c log_file -a /shared/home/${CUSER}/expect.log" ${HOMEDIR}/expect.sh
sed -i -e "7c spawn env LANG=C /shared/home/${CUSER}/anaconda/bin/jupyter-notebook password" ${HOMEDIR}/expect.sh
expect -d ${HOMEDIR}/expect.sh
chown ${CUSER}:${CUSER} ${HOMEDIR}/expect.log
set -u
# password replace
# 2020/12/22
mv ${CYCLECLOUD_SPEC_PATH}/files/jupyter_notebook_config.json ${HOMEDIR}/.jupyter/
JUPUYERSHA1=$(awk -F\" '/"password"/{print $4}' ${HOMEDIR}/.jupyter/jupyter_notebook_config.json)
sed -i -e "281c c.NotebookApp.password = '${JUPUYERSHA1}'" ${HOMEDIR}/.jupyter/jupyter_notebook_config.py

# Token enable and setting: トークンの有効化と設定
set +u
JUPYTERLABTOKEN=$(jetpack config JUPYTERLABTOKEN)
if [[ ! -z ${JUPYTERLABTOKEN} ]]; then 
    sed -i -e "s/# c.NotebookApp.token = '<generated>'/c.NotebookApp.token = '${JUPYTERLABTOKEN}'/g" ${HOMEDIR}/.jupyter/jupyter_notebook_config.py
fi
set -u

# ssl config: SSL設定
sudo -u ${CUSER} openssl req -x509 -nodes -newkey rsa:2048 -keyout ${HOMEDIR}/.jupyter/mycert.key -out ${HOMEDIR}/.jupyter/mycert.pem -passout pass:${JUPYTERLAB_PASS} -subj "/C=JP/ST=TOKYO/L=Minato/O=MSFT Corporation/OU=MSFT/CN= CA/emailAddress=hirost@microsoft.com"
chown ${CUSER}:${CUSER} ${HOMEDIR}/.jupyter/mycert.pem
chown ${CUSER}:${CUSER} ${HOMEDIR}/.jupyter/mycert.key 
# needs privilege pem and key file at user
sed -i -e "102c c.NotebookApp.certfile = u'/shared/home/${CUSER}/.jupyter/mycert.pem'" ${HOMEDIR}/.jupyter/jupyter_notebook_config.py
sed -i -e "223c c.NotebookApp.keyfile = u'/shared/home/${CUSER}/.jupyter/mycert.key'" ${HOMEDIR}/.jupyter/jupyter_notebook_config.py

# systemctl service set up
cp -rf ${CYCLECLOUD_SPEC_PATH}/files/jupyterlab.service ${HOMEDIR}/jupyterlab.service
chown -R ${CUSER}:${CUSER} ${HOMEDIR}/jupyterlab.service 
# 
sed -i -e "s/\${ANACONDAENVNAME}/${ANACONDAENVNAME}/g" ${HOMEDIR}/jupyterlab.service
sed -i -e "s/\${CUSER}/${CUSER}/g" ${HOMEDIR}/jupyterlab.service
sed -i -e "s:\${HOMEDIR}:${HOMEDIR}:g" ${HOMEDIR}/jupyterlab.service

cp -rf ${HOMEDIR}/jupyterlab.service /etc/systemd/system/jupyterlab.service 
mv ${HOMEDIR}/jupyterlab.service ${HOMEDIR}/.jupyter/jupyterlab.service
systemctl stop jupyterlab
systemctl daemon-reload
source ${HOMEDIR}/anaconda/etc/profile.d/conda.sh
conda activate ${ANACONDAENVNAME}
systemctl start jupyterlab
systemctl status jupyterlab

# パーミッションの修正
chown -R ${CUSER}:${CUSER} ${HOMEDIR}/anaconda 

# あとからAzure CycleCloudがユーザ追加した場合に自動でユーザ追加するためのスクリプト実行
#cp -rf ${CYCLECLOUD_SPEC_PATH}/files/addusershell.sh ${HOMEDIR}/addusershell.sh
#chown ${CUSER}:${CUSER} ${HOMEDIR}/addusershell.sh
#chmod +x ${HOMEDIR}/addusershell.sh
# add script to .bashrc
#set +eu
#CMD2=$(grep addusershell ${HOMEDIR}/.bashrc)
#set -eu


popd
rm -rf $tmpdir

echo "end of 20.ubuntu18.04-${SW}.sh"
