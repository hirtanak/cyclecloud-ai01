#!/bin/bash
# Copyright (c) 2020 Hiroshi Tanaka, hirtanak@gmail.com @hirtanak
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
HOMEDIR=/shared/home/${CUSER}
CYCLECLOUD_SPEC_PATH=/mnt/cluster-init/ai01/scheduler
# get palrform
PLATFORM=$(jetpack config platform)
PLATFORM_VERSION=$(jetpack config platform_version)
JUPYTERHUB_INSTALL=$(jetpack config JUPYTERHUB_INSTALL)
JUPYTERHUB_USER_PASS=$(jetpack config JUPYTERHUB_USER_PASS)

# Create tempdir
tmpdir=$(mktemp -d)
pushd $tmpdir


if [[ ${JUPYTERHUB_INSTALL} == "True" ]] || [[ ${JUPYTERHUB_INSTALL} == "true" ]]; then 
    echo "pass to the following steps"
    else 
    echo "end of this script" && exit 0  
fi

set +eu
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
set -u

# c.JupyterHub.spawner_class = 'sudospawner.SudoSpawner' 利用に必要なパッケージ
${HOMEDIR}/anaconda/bin/conda install -n ${ANACONDAENVNAME} -c conda-forge jupyterhub nodejs sudospawner jupyterhub-systemdspawner

# generate jupyterhub configfile
${HOMEDIR}/anaconda/envs/${ANACONDAENVNAME}/bin/jupyterhub --generate-config
# /tmpのテンポラリディレクトリに作成される
mv jupyterhub_config.py ${HOMEDIR}/.jupyter/jupyterhub_config.py | exit 0
chown ${CUSER}:${CUSER} ${HOMEDIR}/.jupyter/jupyterhub_config.py | exit 0

# modify jupyter_notebook_config.py
# Jupyterhubポートセッティング
sed -i -e "s!# c.JupyterHub.bind_url = 'http://:8000'!c.JupyterHub.bind_url = 'http://:8443'!" ${HOMEDIR}/.jupyter/jupyterhub_config.py
sed -i -e "s!# c.JupyterHub.hub_port = 8081!c.JupyterHub.hub_port = 8444!" ${HOMEDIR}/.jupyter/jupyterhub_config.py

# デフォルトでjupyter labを用いたいため以下を修正
sed -i -e "s:# c.Spawner.default_url = '':c.Spawner.default_url = '/lab':" ${HOMEDIR}/.jupyter/jupyterhub_config.py

# adminユーザを追加 (一般ユーザーの接続を切断する権限有)
JUPYTER_ADMIN=jupyterhub
## 初期化
userdel ${JUPYTER_ADMIN} | exit 0

groupadd ${JUPYTER_ADMIN} | exit 0
useradd -m ${JUPYTER_ADMIN} -g ${JUPYTER_ADMIN} --home-dir /shared/home/${JUPYTER_ADMIN} --password ${JUPYTERHUB_USER_PASS} -s /bin/bash | exit 0
mkdir -p /shared/home/${JUPYTER_ADMIN}/notebook
chown ${JUPYTER_ADMIN}:${JUPYTER_ADMIN} /shared/home/${JUPYTER_ADMIN}/notebook | exit 0

gpasswd -a ${JUPYTER_ADMIN} ${SCRIPTUSER} | exit 0
usermod -aG ${SCRIPTUSER} ${JUPYTER_ADMIN} | exit 0

gpasswd -a ${JUPYTER_ADMIN} sudo | exit 0
usermod -aG sudo ${JUPYTER_ADMIN} | exit 0

gpasswd -a ${JUPYTER_ADMIN} root | exit 0
usermod -aG root ${JUPYTER_ADMIN} | exit 0

grep -e ${SCRIPTUSER} -e ${JUPYTER_ADMIN} /etc/passwd
grep -e ${SCRIPTUSER} -e ${JUPYTER_ADMIN} /etc/group 

## adminユーザ追加
sed -i -e "s/^# c.Authenticator.admin_users = set()/c.Authenticator.admin_users = {'${SCRIPTUSER}', '${JUPYTER_ADMIN}'}/" ${HOMEDIR}/.jupyter/jupyterhub_config.py

# 認証方法設定
sed -i -e "s/# c.JupyterHub.spawner_class = 'jupyterhub.spawner.LocalProcessSpawner'/c.JupyterHub.spawner_class = 'sudospawner.SudoSpawner'/" ${HOMEDIR}/.jupyter/jupyterhub_config.py
sed -i -e "566c c.SudoSpawner.sudospawner_path = '${HOMEDIR}/anaconda/envs/py37/bin/sudospawner'" ${HOMEDIR}/.jupyter/jupyterhub_config.py

# アクセスしたら各ユーザーディレクトリのnotebookフォルダを参照するように設定 必須設定項目ではない
#'c.Spawner.notebook_dir'を設定した場合、'各ユーザのnotebookディレクトリ(~/notebook)は事前に作成が必要。
mkdir -p ${HOMEDIR}/notebook
chown ${CUSER}:${CUSER} ${HOMEDIR}/notebook
sed -i -e "s:^# c.Spawner.notebook_dir = '':c.Spawner.notebook_dir = '~/notebook':" ${HOMEDIR}/.jupyter/jupyterhub_config.py

###ユーザ差し替え--------------------------------------
set +u
cat /etc/passwd | grep "/bin/bash" | cut -d: -f1 > ${HOMEDIR}/chekceduser-tmp.txt

# ユーザ除外
cat ${HOMEDIR}/chekceduser-tmp.txt | sed '/root/d' | sed '/cyclecloud/d' | sed '/nxautomation/d' | sed '/omsagent/d' | sed "/${CUSER}/d" | sed "/${SCRIPTUSER}/d" > ${HOMEDIR}/chekceduser.txt
chown ${CUSER}:${CUSER} ${HOMEDIR}/chekceduser.txt

# 人数割り出し
LINES=$(cat ${HOMEDIR}/chekceduser.txt | wc -l )

# パスワード設定
cat ${HOMEDIR}/chekceduser.txt | while read line
do
#    echo ${JUPYTERHUB_USER_PASS} | passwd --stdin $line 
    echo "$line:${JUPYTERHUB_USER_PASS}" | chpasswd
done

# アポストロフィー処理
sed "s/^/'/g" ${HOMEDIR}/chekceduser.txt > ${HOMEDIR}/chekceduser-tmp1.txt
sed -e "s/$/\'/" ${HOMEDIR}/chekceduser-tmp1.txt > ${HOMEDIR}/chekceduser.txt
cat ${HOMEDIR}/chekceduser.txt
rm ${HOMEDIR}/chekceduser-tmp*.txt
#cat ${HOMEDIR}/chekceduser.txt
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
        # "Error adding user testuser01,testuser02 already in db" への対応 
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

## 2020/12/25 対策: pam_loginuid(login:session): Error writing /proc/self/loginuid: Operation not permitted #### pam_loginuid(login:session): set_loginuid failed
chmod 755 /proc/self/loginuid | exit 0
export PATH=/shared/home/azureuser/anaconda/envs/py37/bin/:$PATH

# systemctl service set up
cp -rf ${CYCLECLOUD_SPEC_PATH}/files/jupyterhub.service ${HOMEDIR}/jupyterhub.service
chown -R ${CUSER}:${CUSER} ${HOMEDIR}/jupyterhub.service
# 
sed -i -e "s/\${ANACONDAENVNAME}/${ANACONDAENVNAME}/g" ${HOMEDIR}/jupyterhub.service
sed -i -e "s/\${CUSER}/${CUSER}/g" ${HOMEDIR}/jupyterhub.service
sed -i -e "s:\${HOMEDIR}:${HOMEDIR}:g" ${HOMEDIR}/jupyterhub.service

cp -rf ${HOMEDIR}/jupyterhub.service /etc/systemd/system/jupyterhub.service
mv ${HOMEDIR}/jupyterhub.service ${HOMEDIR}/.jupyter/jupyterhub.service
systemctl stop jupyterhub
systemctl daemon-reload
source ${HOMEDIR}/anaconda/etc/profile.d/conda.sh
conda activate ${ANACONDAENVNAME}
systemctl start jupyterhub
systemctl status jupyterhub

# パーミッションの修正
chown -R ${CUSER}:${CUSER} ${HOMEDIR}/anaconda


popd
rm -rf $tmpdir

echo "end of 21.ubuntu18.04-${SW}.sh"
