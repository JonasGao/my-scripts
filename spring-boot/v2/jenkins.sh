#!/bin/bash

set -e
set -u

## 配置区

APP="xxxxxxx"

REMOTE_DEST="/data/deploy/${APP}"

LOCAL_SRC="${WORKSPACE}/target/${APP}.jar"

REMOTE_CONTROL="${REMOTE_DEST}/control.sh"

REMOTE_USER="xuser"

REMOTE_HOSTS=("x.x.x.x")

## 函数区

function do_control_tomcat ()
{
  local HOST=$1
  local CMD=$2

  echo "> 远程 $HOST 执行 $CMD $APP"
  ssh "${REMOTE_USER}@${HOST}" "${REMOTE_CONTROL} $CMD"
}

function do_sync ()
{
  local HOST=$1

  echo "> 上传 $APP 制品 ${LOCAL_SRC} 到 $HOST:${REMOTE_DEST}"
  #rsync -zvr --delete $LOCAL_SRC "${REMOTE_USER}@${HOST}:${REMOTE_DEST}"
  scp "$LOCAL_SRC" "${REMOTE_USER}@${HOST}:${REMOTE_DEST}"
}

function do_deploy ()
{
  local HOST=$1

  do_control_tomcat $HOST stop
  do_sync $HOST
  do_control_tomcat $HOST start
}

function deploy ()
{
  printf "\n> 打包结束，开始进行部署\n"
  for webAppHost in ${REMOTE_HOSTS[@]}
  do
    printf "\n> 准备发布到 $webAppHost\n"
    do_deploy $webAppHost
  done
  printf "\n> 部署结束\n"
}

#####################
#      开始执行      #
#####################

deploy
