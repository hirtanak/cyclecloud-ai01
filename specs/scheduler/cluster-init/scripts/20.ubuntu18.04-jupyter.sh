#!/bin/bash
# Copyright (c) 2020-2021 Hiroshi Tanaka, hirtanak@gmail.com @hirtanak
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
# jupyterlab
JUPYTERLAB_VERSION=$(jetpack config JUPYTERLAB_VERSION)
JUPYTERLAB_PASS=$(jetpack config JUPYTERLAB_PASS)
# jupyterhub
JUPYTERHUB_INSTALL=$(jetpack config JUPYTERHUB_INSTALL)

# Create tempdir
tmpdir=$(mktemp -d)
pushd $tmpdir


if [[ ${PLATFORM} == "ubuntu" ]] && [[ ${PLATFORM_VERSION} == "18.04" ]]; then 
   echo "pass to the following steps"
   else 
   echo "end of this script" && exit 0  
fi

# anaconda setting
ANACONDAENVNAME=$(jetpack config ANACONDAENVNAME)
ANACONDAPYTHON_VERSION=$(jetpack config ANACONDAPYTHON_VERSION)
ANACONDAPACKAGE=$(jetpack config ANACONDAPACKAGE)

# セットアップの手順
# 1. conda install -c conda-forge jupyterlab
# 2. jupyter lab --ip=0.0.0.0 --no-browser# 
# 3. ~/anaconda/envs/py37/bin$ jupyter-lab --generate-config
# 4. c.NotebookApp.port = 8888
# 5. #c.NotebookApp.ip = 'localhost'

# set up directry and privillege
mkdir -p ${HOMEDIR}/.jupyter/
chown -R ${CUSER}:${CUSER} ${HOMEDIR}/.jupyter/

# jupyterlab package インストール
if [[ ${JUPYTERHUB_INSTALL} == "True" ]] || [[ ${JUPYTERHUB_INSTALL} == "true" ]]; then
    echo "時間がかかるので必須でない場合パスする"
else
    echo "jupyterhubがインストールされない場合にインストールする"
    ${HOMEDIR}/anaconda/bin/conda install -n ${ANACONDAENVNAME} -c conda-forge nodejs==14.15.1
fi
${HOMEDIR}/anaconda/bin/conda install -n ${ANACONDAENVNAME} -c conda-forge jupyterlab==${JUPYTERLAB_VERSION}

# generate jupyter-lab configfile
if [[ -f ${HOMEDIR}/.jupyter/jupyter_lab_config.py ]]; then
    rm /.jupyter/jupyter_lab_config.py | exit 0 
    ${HOMEDIR}/anaconda/envs/${ANACONDAENVNAME}/bin/jupyter-lab --generate-config -y
    mv /.jupyter/jupyter_lab_config.py ${HOMEDIR}/.jupyter/jupyter_lab_config.py || mv /.jupyter/jupyter_notebook_config.py ${HOMEDIR}/.jupyter/jupyter_lab_config.py
    cp ${HOMEDIR}/.jupyter/jupyter_lab_config.py ${HOMEDIR}/.jupyter/jupyter_lab_config.py.original | exit 0
else 
    ${HOMEDIR}/anaconda/envs/${ANACONDAENVNAME}/bin/jupyter-lab --generate-config -y
    mv /.jupyter/jupyter_lab_config.py ${HOMEDIR}/.jupyter/jupyter_lab_config.py || mv /.jupyter/jupyter_notebook_config.py ${HOMEDIR}/.jupyter/jupyter_lab_config.py
fi
chown ${CUSER}:${CUSER} ${HOMEDIR}/.jupyter/jupyter_lab_config.py | exit 0

# modify jupyter_lab_config.py: コンフィグの作成
sed -i -e "s/^# c.NotebookApp.port = 8888/c.LabServerApp.port = 443/g" ${HOMEDIR}/.jupyter/jupyter_lab_config.py
sed -i -e "s/^# c.NotebookApp.ip = 'localhost'/c.LabServerApp.ip = '0.0.0.0'/g" ${HOMEDIR}/.jupyter/jupyter_lab_config.py
# Other config
sed -i -e "s/^# c.LabApp.open_browser = True/c.LabApp.open_browser = False/g" ${HOMEDIR}/.jupyter/jupyter_lab_config.py
# 2020/12/22 対応 Token設定
sed -i -e "s/Default: ''/#Default: ''/g" ${HOMEDIR}/.jupyter/jupyter_lab_config.py

# password set up: パスワードの設定
if [[ ${JUPYTERLAB_PASS} = None ]]; then
   JUPYTERLAB_PASS=password123!
fi
# expect
#apt-get install -y expect
#cp -rf ${CYCLECLOUD_SPEC_PATH}/files/expect.sh ${HOMEDIR}/expect.sh
#chown ${CUSER}:${CUSER} ${HOMEDIR}/expect.sh
#chmod +x ${HOMEDIR}/expect.sh
#set +u
#sed -i -e "s/EXPECTPASSWORD/${JUPYTERLAB_PASS}/g" ${HOMEDIR}/expect.sh
#sed -i -e "3c log_file -a /shared/home/${CUSER}/expect.log" ${HOMEDIR}/expect.sh
#sed -i -e "7c spawn env LANG=C /shared/home/${CUSER}/anaconda/bin/jupyter-notebook password" ${HOMEDIR}/expect.sh
#expect -d ${HOMEDIR}/expect.sh
#chown ${CUSER}:${CUSER} ${HOMEDIR}/expect.log
#set -u
# password replace 2020/12/22
#mv ${CYCLECLOUD_SPEC_PATH}/files/jupyter_notebook_config.json ${HOMEDIR}/.jupyter/
#chown ${CUSER}:${CUSER} ${HOMEDIR}/.jupyter/jupyter_notebook_config.json
sed -i -e "s/# c.LabApp.password = ''/c.LabServerApp.password = '${JUPYTERLAB_PASS}'/" ${HOMEDIR}/.jupyter/jupyter_lab_config.py

# Token enable and setting: トークンの有効化と設定
set +u
JUPYTERLABTOKEN=$(jetpack config JUPYTERLABTOKEN)
if [[ ! -z ${JUPYTERLABTOKEN} ]]; then 
    sed -i -e "s/# c.NotebookApp.token = '<generated>'/c.LabServerApp.token = '${JUPYTERLABTOKEN}'/g" ${HOMEDIR}/.jupyter/jupyter_lab_config.py
fi
set -u

# ssl config: SSL設定
sudo -u ${CUSER} openssl req -x509 -nodes -newkey rsa:2048 -keyout ${HOMEDIR}/.jupyter/mycert.key -out ${HOMEDIR}/.jupyter/mycert.pem -passout pass:${JUPYTERLAB_PASS} -subj "/C=JP/ST=TOKYO/L=Minato/O=MSFT Corporation/OU=MSFT/CN= CA/emailAddress=hirost@microsoft.com"
chown ${CUSER}:${CUSER} ${HOMEDIR}/.jupyter/mycert.pem
chown ${CUSER}:${CUSER} ${HOMEDIR}/.jupyter/mycert.key 
# needs privilege pem and key file at user
sed -i -e "102c c.LabServerApp.certfile = u'${HOMEDIR}/.jupyter/mycert.pem'" ${HOMEDIR}/.jupyter/jupyter_lab_config.py
sed -i -e "223c c.LabServerApp.keyfile = u'${HOMEDIR}/.jupyter/mycert.key'" ${HOMEDIR}/.jupyter/jupyter_lab_config.py

# 2020/12/26 追加: jupyterhubが有効であれば事前に実行しておく
if [[ ${JUPYTERHUB_INSTALL} == "True" ]] || [[ ${JUPYTERHUB_INSTALL} == "true" ]]; then
    JUPYTER_ADMIN=jupyterhub
    sed -i -e "307c c.LabServerApp.kernel_spec_manager_class='environment_kernels.EnvironmentKernelSpecManager'" ${HOMEDIR}/.jupyter/jupyter_lab_config.py
    sed -i -e "308c c.EnvironmentKernelSpecManager.env_dirs=['/shared/home/${JUPYTER_ADMIN}/anaconda/envs/']" ${HOMEDIR}/.jupyter/jupyter_lab_config.py
    sed -i -e "309c c.EnvironmentKernelSpecManager.conda_env_dirs=['/shared/home/${JUPYTER_ADMIN}/anaconda/envs/']" ${HOMEDIR}/.jupyter/jupyter_lab_config.py
fi

# systemctl service set up
if [[ ${JUPYTERHUB_INSTALL} == "True" ]] || [[ ${JUPYTERHUB_INSTALL} == "true" ]]; then
    # jupyterhubが実行される場合、あとでサービス化する
    echo "skip"
else
    # jupyterhubが実行されない場合のサービス化
    cp -rf ${CYCLECLOUD_SPEC_PATH}/files/jupyterlab.service ${HOMEDIR}/jupyterlab.service
    chown ${CUSER}:${CUSER} ${HOMEDIR}/jupyterlab.service 
    # サービス化ファイルの変更 
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
fi

# .bashrc 追加
set +eu
(grep conda.sh ${HOMEDIR}/.bashrc | head -1) > /shared/CONDA1
(grep "conda activate" ${HOMEDIR}/.bashrc | head -1) > /shared/CONDA2
CMD1=$(cat /shared/CONDA1)
CMD2=$(cat /shared/CONDA2)
if [[ -z ${CMD1} ]]; then
    (echo "source ${HOMEDIR}/anaconda/etc/profile.d/conda.sh") >> ${HOMEDIR}/.bashrc
fi
if [[ ! -z ${CMD1} ]] && [[ -z ${CMD2} ]]; then
    (echo "conda activate ${ANACONDAENVNAME}") >> ${HOMEDIR}/.bashrc
fi
set -eu

# パーミッションの修正
chown -R ${CUSER}:${CUSER} ${HOMEDIR}/anaconda 

# 削除予定
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
