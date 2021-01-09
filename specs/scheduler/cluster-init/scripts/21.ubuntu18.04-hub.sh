#!/bin/bash
# Copyright (c) 2020-2021 Hiroshi Tanaka, hirtanak@gmail.com @hirtanak
set -exuv

SW=hub
echo "starting 21.ubuntu18.04-${SW}.sh"

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
JUPYTER_ADMIN=$(jetpack config JUPYTER_ADMIN)
HOMEDIR=/shared/home/${JUPYTER_ADMIN}
CYCLECLOUD_SPEC_PATH=/mnt/cluster-init/ai01/scheduler
# get palrform
PLATFORM=$(jetpack config platform)
PLATFORM_VERSION=$(jetpack config platform_version)
# jupyterlab 設定
JUPYTERLAB_VERSION=$(jetpack config JUPYTERLAB_VERSION)
JUPYTERHUB_INSTALL=$(jetpack config JUPYTERHUB_INSTALL)
JUPYTERHUB_USER_PASS=$(jetpack config JUPYTERHUB_USER_PASS)
# anaconda パラメータ
ANACONDAENVNAME=$(jetpack config ANACONDAENVNAME)
ANACONDAPYTHON_VERSION=$(jetpack config ANACONDAPYTHON_VERSION)
ANACONDAPACKAGE=$(jetpack config ANACONDAPACKAGE)
# jupyterhub ユーザ作成
userdel ${JUPYTER_ADMIN} | exit 0

groupadd ${JUPYTER_ADMIN} -g 19000 | exit 0
useradd -m ${JUPYTER_ADMIN} -g ${JUPYTER_ADMIN} --home-dir ${HOMEDIR} -u 19000 --password ${JUPYTERHUB_USER_PASS} -s /bin/bash | exit 0
mkdir -p /shared/home/${JUPYTER_ADMIN}/notebook
chown ${JUPYTER_ADMIN}:${JUPYTER_ADMIN} ${HOMEDIR}/notebook | exit 0

# 権限・グループ設定
usermod -aG ${SCRIPTUSER} ${JUPYTER_ADMIN} | exit 0
usermod -aG sudo ${JUPYTER_ADMIN} | exit 0
#usermod -aG root ${JUPYTER_ADMIN} | exit 0

grep -e ${SCRIPTUSER} -e ${JUPYTER_ADMIN} /etc/passwd
grep -e ${SCRIPTUSER} -e ${JUPYTER_ADMIN} /etc/group

# SSH設定ファイルコピー
cp -rf /shared/home/${CUSER}/.ssh ${HOMEDIR}
chown ${JUPYTER_ADMIN}:${JUPYTER_ADMIN} ${HOMEDIR}/.ssh

# ディレクトリ作成
mkdir -p ${HOMEDIR}/.jupyter
chown ${JUPYTER_ADMIN}:${JUPYTER_ADMIN} ${HOMEDIR}/.jupyter

# Create tempdir
tmpdir=$(mktemp -d)
pushd $tmpdir


if [[ ${JUPYTERHUB_INSTALL} == "True" ]] || [[ ${JUPYTERHUB_INSTALL} == "true" ]]; then 
    echo "pass to the following steps"
    else 
    echo "end of this script" && exit 0  
fi

if [[ ! -d ${HOMEDIR}/anaconda ]]; then 
    cp /shared/home/${CUSER}/anaconda.sh ${HOMEDIR}/
    chown ${JUPYTER_ADMIN}:${JUPYTER_ADMIN} ${HOMEDIR}/anaconda.sh
    sudo -u ${JUPYTER_ADMIN} bash ${HOMEDIR}/anaconda.sh -b -p ${HOMEDIR}/anaconda
fi

# 環境作成
# c.JupyterHub.spawner_class = 'sudospawner.SudoSpawner' 利用に必要なパッケージ
${HOMEDIR}/anaconda/bin/conda create -n ${JUPYTER_ADMIN} python=${ANACONDAPYTHON_VERSION}
if [[ ! -f ${HOMEDIR}/anaconda/envs/jupyterhub/bin/node ]]; then
    ${HOMEDIR}/anaconda/bin/conda install -n ${JUPYTER_ADMIN} -c conda-forge nodejs==14.15.1
fi
# install node js npm and n package
set +eu
CMD=$(node -v) 
echo ${CMD%%.*}
if [[ -z ${CMD} ]]; then 
    apt-get install -y nodejs npm 
    npm install n -g
    n lts
    npm install -g configurable-http-proxy
    apt purge -y nodejs npm
    node -v
else 
    echo "skip to install"
fi
set -eu

# パッケージインストール
${HOMEDIR}/anaconda/bin/conda install -n ${JUPYTER_ADMIN} -c conda-forge jupyterlab==${JUPYTERLAB_VERSION} jupyterhub==1.3.0 sudospawner configurable-http-proxy jupyterhub-systemdspawner ipython ipykernel git

# generate jupyterhub configfile
if [[ ! -f ${HOMEDIR}/.jupyter/jupyterhub_config.py ]]; then 
    ${HOMEDIR}/anaconda/envs/${JUPYTER_ADMIN}/bin/jupyterhub --generate-config
fi
# /tmpのテンポラリディレクトリに作成される。ファイル移動
mv jupyterhub_config.py ${HOMEDIR}/.jupyter/jupyterhub_config.py | exit 0
chown ${JUPYTER_ADMIN}:${JUPYTER_ADMIN} ${HOMEDIR}/.jupyter/jupyterhub_config.py | exit 0
cp ${HOMEDIR}/.jupyter/jupyterhub_config.py ${HOMEDIR}/.jupyter/jupyterhub_config.py.original | exit 0

# jupyter_notebook_config.py の修正: Jupyterhubポートセッティング
sed -i -e "s!# c.JupyterHub.bind_url = 'http://:8000'!c.JupyterHub.bind_url = 'http://:8443'!" ${HOMEDIR}/.jupyter/jupyterhub_config.py
sed -i -e "s!# c.JupyterHub.hub_port = 8081!c.JupyterHub.hub_port = 8444!" ${HOMEDIR}/.jupyter/jupyterhub_config.py

# デフォルトでjupyter labを利用するため以下を修正
sed -i -e "s:# c.Spawner.default_url = '':c.Spawner.default_url = '/lab':" ${HOMEDIR}/.jupyter/jupyterhub_config.py

# adminユーザを追加 (一般ユーザーの接続を切断する権限有)
sed -i -e "s/^# c.Authenticator.admin_users = set()/c.Authenticator.admin_users = {'${SCRIPTUSER}', '${JUPYTER_ADMIN}'}/" ${HOMEDIR}/.jupyter/jupyterhub_config.py

# 認証方法設定: 正しく設定しないとInternal Server Error 500 API Error
sed -i -e "s/# c.JupyterHub.spawner_class = 'jupyterhub.spawner.LocalProcessSpawner'/c.JupyterHub.spawner_class = 'sudospawner.SudoSpawner'/" ${HOMEDIR}/.jupyter/jupyterhub_config.py
sed -i -e "594c c.SudoSpawner.sudospawner_path = '${HOMEDIR}/anaconda/envs/${JUPYTER_ADMIN}/bin/sudospawner'" ${HOMEDIR}/.jupyter/jupyterhub_config.py

# アクセスしたら各ユーザーディレクトリのnotebookフォルダを参照するように設定 
#'c.Spawner.notebook_dir'を設定した場合、'各ユーザのnotebookディレクトリ(~/notebook)は事前に作成が必要。
mkdir -p ${HOMEDIR}/notebook
chown ${JUPYTER_ADMIN}:${JUPYTER_ADMIN} ${HOMEDIR}/notebook
#sed -i -e "s:^# c.Spawner.notebook_dir = '':c.Spawner.notebook_dir = '~/notebook':" ${HOMEDIR}/.jupyter/jupyterhub_config.py

###追加利用ユーザ設定(jupyterhub)--------------------------------------
set +u
cat /etc/passwd | grep "/bin/bash" | cut -d: -f1 > ${HOMEDIR}/chekceduser-tmp.txt

# ユーザ除外
cat ${HOMEDIR}/chekceduser-tmp.txt | sed '/root/d' | sed '/cyclecloud/d' | sed '/nxautomation/d' | sed '/omsagent/d' | sed "/${SCRIPTUSER}/d" > ${HOMEDIR}/chekceduser.txt
chown ${JUPYTER_ADMIN}:${JUPYTER_ADMIN} ${HOMEDIR}/chekceduser.txt

# 人数割り出し
LINES=$(cat ${HOMEDIR}/chekceduser.txt | wc -l )

# ユーザ設定
cat ${HOMEDIR}/chekceduser.txt | while read line
do
    # パスワード変更
    echo "$line:${JUPYTERHUB_USER_PASS}" | chpasswd
    # conda 設定
    set +eu
    CMD=$(grep conda.sh /shared/home/$line/.bashrc)
    if [[ ! -z $line ]]; then
        (echo "source ${HOMEDIR}/anaconda/etc/profile.d/conda.sh") >> /shared/home/$line/.bashrc
    fi
    set -eu
done

# アポストロフィー処理
sed "s/^/'/g" ${HOMEDIR}/chekceduser.txt > ${HOMEDIR}/chekceduser-tmp1.txt
sed -e "s/$/\'/" ${HOMEDIR}/chekceduser-tmp1.txt > ${HOMEDIR}/chekceduser.txt
cat ${HOMEDIR}/chekceduser.txt
rm ${HOMEDIR}/chekceduser-tmp*.txt
LINES=$(cat ${HOMEDIR}/chekceduser.txt | wc -l )

# jupyterhub_config.py 設定変更
case ${LINES} in
    0 | 1 )
        echo "skip replace none or one"
    ;;
    * )
    # ", " へ変換
    CHECKUSER=$(cat ${HOMEDIR}/chekceduser.txt | tr '\n' ', ' | sed -e 's/,$/\n/g')
    # 既存設定
    CONFIGUSERLINE=$(grep "c.Authenticator.whitelist" ${HOMEDIR}/.jupyter/jupyterhub_config.py)
    if [[ ${CONFIGUSERLINE} == "# c.Authenticator.whitelist = set()" ]]; then 
        # "Error adding user <username> already in db" への対応 
        rm /shared/home/azureuser/.jupyter/jupyterhub.sqlite | exit 0
    	# オリジナルのままの場合の変換
	sed -i -e "s/# c.Authenticator.whitelist = set()/c.Authenticator.whitelist = {${CHECKUSER}}/" ${HOMEDIR}/.jupyter/jupyterhub_config.py
    else
#	CONFIGUSER=$(echo ${CONFIGUSERLINE} | sed 's/^.*"\(.*\)".*$/\1/')
        echo "later update"	
    fi	
    ;;
esac

set -u
###----------------------------------------------------

###----------------------------------------------------
# ssl config: SSL設定(mycert.key, mykey.key)は20.で作成済み
sed -i -e "s!# c.JupyterHub.ssl_cert = ''!c.JupyterHub.ssl_cert = u'/shared/home/${CUSER}/.jupyter/mycert.pem'!" ${HOMEDIR}/.jupyter/jupyterhub_config.py
sed -i -e "s!# c.JupyterHub.ssl_key = ''!c.JupyterHub.ssl_key = u'/shared/home/${CUSER}/.jupyter/mycert.key'!" ${HOMEDIR}/.jupyter/jupyterhub_config.py
###----------------------------------------------------

###拡張機能--------------------------------------------
## 2020/12/25 対策: pam_loginuid(login:session): 
chmod 755 /proc/self/loginuid | exit 0
export PATH=${HOMEDIR}/anaconda/envs/${JUPYTER_ADMIN}/bin/:$PATH

## Configure JupyterHub's Spawner to start with a JupyterLab that is aware of the JupyterHub
sed -i -e "728c c.Spawner.cmd = ['jupyter-labhub']" ${HOMEDIR}/.jupyter/jupyterhub_config.py

jupyter labextension enable
jupyter labextension install -y @jupyterlab/hub-extension

jupyter labextension install -y @lckr/jupyterlab_variableinspector

jupyter labextension install -y @jupyterlab/toc

#${HOMEDIR}/anaconda/bin/conda install -n ${ANACONDAENVNAME} -y -c conda-forge jupyterlab_code_formatter
#jupyter labextension install -y @ryantam626/jupyterlab_code_formatter
#jupyter serverextension enable jupyterlab_code_formatter

#jupyter labextension install -y @jupyterlab/google-drive

#${HOMEDIR}/anaconda/bin/conda install -n ${JUPYTER_ADMIN} ipywidgets

jupyter labextension install -y @jupyter-widgets/jupyterlab-manager

#jupyter nbextension enable --sys-prefix widgetsnbextension

#conda install -c conda-forge jupyterlab-git -y

#### Jupyterlab-Slurm 拡張機能インストール（調整中）
#wget https://github.com/hirtanak/jupyterlab-slurm/archive/master.zip -O ${HOMEDIR}/notebook/master.zip
#source ${HOMEDIR}/anaconda/etc/profile.d/conda.sh
#conda activate ${JUPYTER_ADMIN}
#conda install unzip -y
#unzip -qq ${HOMEDIR}/notebook/master.zip -d ${HOMEDIR}/notebook/
#${HOMEDIR}/anaconda/envs/${JUPYTER_ADMIN}/bin/jlpm install   # Install npm package dependencies
#${HOMEDIR}/anaconda/envs/${JUPYTER_ADMIN}/bin/jlpm run build  # Compile the TypeScript sources to Javascript
#${HOMEDIR}/anaconda/envs/${JUPYTER_ADMIN}/bin/jupyter labextension install  # Install the current directory as an extension

pip install --quiet jupyterlab_slurm
jupyter labextension install jupyterlab-slurm

${HOMEDIR}/anaconda/envs/${JUPYTER_ADMIN}/bin/jupyter-lab build

## 拡張機能確認
jupyter labextension list

###自動起動--------------------------------------------
# jupyterlab サービス化設定・実行
cp -rf ${CYCLECLOUD_SPEC_PATH}/files/jupyterlab.service ${HOMEDIR}/jupyterlab.service
chown  ${JUPYTER_ADMIN}:${JUPYTER_ADMIN} ${HOMEDIR}/jupyterlab.service
# jupyter_lab_config.py ファイルのコピー 
if [[ ! -f ${HOMEDIR}/.jupyter/jupyter_lab_config.py ]]; then 
    cp /shared/home/${CUSER}/.jupyter/jupyter_lab_config.py ${HOMEDIR}/.jupyter/
else
    mv ${HOMEDIR}/.jupyter/jupyter_lab_config.py ${HOMEDIR}/.jupyter/jupyter_lab_config.py.original | exit 0 
    cp /shared/home/${CUSER}/.jupyter/jupyter_lab_config.py ${HOMEDIR}/.jupyter/
fi
chown  ${JUPYTER_ADMIN}:${JUPYTER_ADMIN} ${HOMEDIR}/.jupyter/jupyter_lab_config.py
# サービス化ファイルの変更
sed -i -e "s/\${ANACONDAENVNAME}/${JUPYTER_ADMIN}/g" ${HOMEDIR}/jupyterlab.service
sed -i -e "s/\${CUSER}/${JUPYTER_ADMIN}/g" ${HOMEDIR}/jupyterlab.service
sed -i -e "s:\${HOMEDIR}:${HOMEDIR}:g" ${HOMEDIR}/jupyterlab.service

cp -rf ${HOMEDIR}/jupyterlab.service /etc/systemd/system/jupyterlab.service
mv ${HOMEDIR}/jupyterlab.service ${HOMEDIR}/.jupyter/jupyterlab.service
systemctl stop jupyterlab
systemctl daemon-reload
source ${HOMEDIR}/anaconda/etc/profile.d/conda.sh
conda activate ${JUPYTER_ADMIN}
systemctl start jupyterlab
systemctl status jupyterlab

# jupyterhub サービス化設定・実行
cp -rf ${CYCLECLOUD_SPEC_PATH}/files/jupyterhub.service ${HOMEDIR}/jupyterhub.service
chown ${JUPYTER_ADMIN}:${JUPYTER_ADMIN} ${HOMEDIR}/jupyterhub.service
# サービス化ファイルの変更
sed -i -e "s/\${ANACONDAENVNAME}/${JUPYTER_ADMIN}/g" ${HOMEDIR}/jupyterhub.service
sed -i -e "s/\${CUSER}/${JUPYTER_ADMIN}/g" ${HOMEDIR}/jupyterhub.service
sed -i -e "s:\${HOMEDIR}:${HOMEDIR}:g" ${HOMEDIR}/jupyterhub.service

cp -rf ${HOMEDIR}/jupyterhub.service /etc/systemd/system/jupyterhub.service
mv ${HOMEDIR}/jupyterhub.service ${HOMEDIR}/.jupyter/jupyterhub.service
systemctl stop jupyterhub
systemctl daemon-reload
source ${HOMEDIR}/anaconda/etc/profile.d/conda.sh
conda activate ${JUPYTER_ADMIN}
systemctl start jupyterhub
systemctl status jupyterhub

# .bashrc 修正
set +eu 
CMD1=$(grep conda.sh ${HOMEDIR}/.bashrc | head -1)
CMD2=$(grep "conda activate" ${HOMEDIR}/.bashrc | head -1)
if [[ -z ${CMD1} ]] && [[ -z ${CMD2} ]]; then
    (echo "source ${HOMEDIR}/anaconda/etc/profile.d/conda.sh"; echo "conda activate ${JUPYTER_ADMIN}") >> ${HOMEDIR}/.bashrc
fi
if [[ ! -z ${CMD1} ]] && [[ -z ${CMD2} ]]; then
    (echo "conda activate ${JUPYTER_ADMIN}") >> ${HOMEDIR}/.bashrc
fi
set -eu

# Jupyterhub/lab 環境追加スクリプト設定
cp -rf ${CYCLECLOUD_SPEC_PATH}/files/addcondaenv.sh ${HOMEDIR}/addcondaenv.sh
chmod +x ${HOMEDIR}/addcondaenv.sh
chown ${JUPYTER_ADMIN}:${JUPYTER_ADMIN} ${HOMEDIR}/addcondaenv.sh
sed -i -e "s:\${HOMEDIR}:${HOMEDIR}:g" ${HOMEDIR}/addcondaenv.sh

# ログテキスト処理の機能追加
apt install -qq python-pip -y
who
users
sudo -u root pip install --log /root/log01.log TxtStyle
wget -q https://raw.githubusercontent.com/hirtanak/scripts/master/.txts.conf -O /root/.txts.conf
#mkdir -p /.local
#chown ${JUPYTER_ADMIN}:${JUPYTER_ADMIN} /.local
#sudo -u ${JUPYTER_ADMIN} pip install --log ${HOMEDIR}/log01.log TxtStyle
wget -q https://raw.githubusercontent.com/hirtanak/scripts/master/.txts.conf -O ${HOMEDIR}/.txts.conf
chown ${JUPYTER_ADMIN}:${JUPYTER_ADMIN} ${HOMEDIR}/.txts.conf

# パーミッションの修正
chown -R ${JUPYTER_ADMIN}:${JUPYTER_ADMIN} ${HOMEDIR}

CMD=$(curl -s ifconfig.io)
echo "https://${CMD}:8443" 


popd
rm -rf $tmpdir

echo "end of 21.ubuntu18.04-${SW}.sh"
