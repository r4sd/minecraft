#!/bin/bash

SERVICE='boot'
USERNAME='minecraft'
MC_PATH='/home/minecraft/minecraft'
BK_PATH='/home/minecraft/backup'
BK_TIME=`date +%Y%m%d-%H%M%S`
BK_NAME="${BK_PATH}/full_data_${BK_TIME}.tar.gz"
BK_GEN="3"

## 作業ディレクトリの確認
if [ ! -e ${MC_PATH} ]; then mkdir -p ${MC_PATH}; fi
if [ ! -e ${BK_PATH} ]; then mkdir -p ${BK_PATH}; fi

cd ${MC_PATH}

## サービス停止前の確認
if pgrep -u ${USERNAME} -f ${SERVICE} > /dev/null
  then
  echo "Full backup start minecraft data..."
  systemctl stop minecraft_server
  sleep 10
  
  echo "Full Backup start ..."
  tar cfvz ${BK_NAME} ${MC_PATH}
  chown minecraft:minecraft ${BK_NAME}
  sleep 10
  
  echo "Full Backup compleate!"
  find ${BK_PATH} -name "${BK_NAME}" -type f -mtime +${BK_GEN} -exec rm {} \;
  echo "Starting ${SERVICE}..."
  systemctl start minecraft_server
  systemctl status minecraft_server
else
  echo "${SERVICE} was not runnning."
fi