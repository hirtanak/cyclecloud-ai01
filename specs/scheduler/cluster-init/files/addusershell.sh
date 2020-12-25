#!/usr/bin/bash

ls -ls /home | awk '{ print $4 }' > ${HOME}/shell

# get script concurrent user
CUSER=`cat /shared/CUSER`
SCRIPTUSER=`cat /shared/SCRIPTUSER`

CHECKUSER=`cat ${HOME}/shell`

while read line
do
  echo $line 
  if [[ ! $line = "${CUSER}" ]] && [[ ! $line = "cyclecloud" ]] && [[ ! $line = "nxautomation" ]]; then
    usermod $line -s /bin/bash 
    # avoid ssh install for new user
    declare SSHKEYPORTINGCUSER
    declare SSHKEYPORTINGCYCLE
    SSHKEYPORTINGCUSER=$(sed -n 3P /home/$line/.ssh/authorized_keys)
    SSHKEYPORTINGCYCLE=$(cat ${HOME}/${CUSER}/SSHKEYPORTINGCYCLE)
    if [[ ${SSHKEYPORTINGCUSER} = "None" ]] || [[ -z ${SSHKEYPORTINGCUSER} ]]; then
      echo ${SSHKEYPORTINGCYCLE} >> /home/$line/.ssh/authorized_keys
    fi
  fi
done << FILE
$CHECKUSER
FILE

