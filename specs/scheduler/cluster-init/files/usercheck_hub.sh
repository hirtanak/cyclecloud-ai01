#!/usr/bin/bash

CMD=$(cat /etc/passwd | grep "/bin/bash" | cut -d: -f1)

# ユーザ除外
CUSER=`cat /shared/CUSER`
SCRIPTUSER=`cat /shared/SCRIPTUSER`

echo ${CMD} | sed '/root/d' | sed '/cyclecloud/d' | sed '/nxautomation/d' | sed "/${CUSER}/d" | sed "/${SCRIPTUSER}/d" > ${HOME}/chekceduser.txt

# アクセス可能なユーザーをホワイトリストへ追加
#echo "c.Authenticator.whitelist = {'User1, User2'}" ${HOMEDIR}/.jupyter/jupyterhub_config.py

CHECKUSER=$(cat ${HOME}/checkeduser.txt | tr '\n' ', ')

CONFIGUSERLINE=$(grep "c.Authenticator.whitelist" ${HOMEDIR}/.jupyter/jupyterhub_config.py)
CONFIGUSER=$(sed 's/^.*"\(.*\)".*$/\1/' ${CONFIGUSERLINE})

if [[ ${CONFIGUSER} != ${CHECKUSER} ]]; then 
    # チェックしたユーザで書き換え
    sed -i -e "s/c.Authenticator.whitelist = {'${CHECKUSER}'}" ${HOMEDIR}/.jupyter/jupyterhub_config.py
fi
