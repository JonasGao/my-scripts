#!/bin/bash

# 当前脚本的名字
PROG_NAME=$0

# 当前脚本的操作参数
ACTION=$1

# 应用启动的工作目录
APP_HOME=$(dirname "$PROG_NAME")

# 目标 jar 包
JAR_NAME="app.jar"

# 应用启动的端口
APP_PORT=8090

# JVM 配置参数
JVM_OPTS="-server -Xmx512m -XX:+UseG1GC -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=$APP_HOME/logs/"

# JAR 包启动的时候传递的参数
JAR_ARGS="--spring.config.location=file:conf/ --server.port=${APP_PORT}"

# 等待应用启动的时间
APP_START_TIMEOUT=20

# 环境配置文件名
SET_ENV_FILENAME="setenv.sh"

# 如果有配置文件，以配置文件覆盖
CWD_SET_ENV=$(readlink -f "./$SET_ENV_FILENAME")
if [ -f "$CWD_SET_ENV" ]; then
  echo "Overwrite with $CWD_SET_ENV"
  source "$CWD_SET_ENV"
fi
APP_HOME_SET_ENV="$APP_HOME/$SET_ENV_FILENAME"
if [ -f "$APP_HOME_SET_ENV" ]; then
  if [ "$APP_HOME_SET_ENV" != "$CWD_SET_ENV" ]; then
    echo "Overwrite with $APP_HOME_SET_ENV"
    source "$APP_HOME_SET_ENV"
  fi
fi

# 应用健康检查URL
[ -z "$HEALTH_CHECK_URL" ] && HEALTH_CHECK_URL="http://127.0.0.1:${APP_PORT}"

# 健康的HTTP代码
[ -z "$HEALTH_HTTP_CODE" ] && HEALTH_HTTP_CODE=(200 404 403 405)

# JAR 包的绝对路径
[ -z "$JAR_PATH" ] && JAR_PATH="${APP_HOME}/${JAR_NAME}"

# 应用的控制台输出
# 例如 STD_OUT=${APP_HOME}/logs/start.log
[ -z "$STD_OUT" ] && STD_OUT="${APP_HOME}/app.log"

# 应用的日志输出路径
[ -z "$APP_LOG_HOME" ] && APP_LOG_HOME=${APP_HOME}

# 应用的日志文件
[ -z "$APP_LOG" ] && APP_LOG=${STD_OUT}

# PID 位置
[ -z "$PID_PATH" ] && PID_PATH="${APP_HOME}/pid"

# 准备相关工具
[ -z "$JAVA" ] && JAVA=$(which java 2>/dev/null)
[ -z "$NOHUP" ] && NOHUP=$(which nohup 2>/dev/null)
[ -z "$PGREP" ] && PGREP=$(which pgrep 2>/dev/null)

# 创建出相关目录
mkdir -p "${APP_HOME}"
mkdir -p "${APP_LOG_HOME}"

# 全局变量
CURR_PID=
OTHER_RUNNING=false

usage() {
  printf """Usage: $PROG_NAME <command>
There are some commands:
  s, start
  t, stop
  r, restart
  p, pid
  c, check
"""
}

if [[ "$TERM" == xterm* ]]; then
  print-step()  { printf "\r%s" "$1"; }
  start-step()  { printf "\r%s" "$1"; }
  append-step() { printf "%s" "$1"; }
  finish-step() { printf "\r%s\n" "$1"; }
else
  print-step()  { printf "%s\n" "$1"; }
  start-step()  { printf "%s" "$1"; }
  append-step() { printf "%s\n" "$1"; }
  finish-step() { printf "%s\n" "$1"; }
fi

curlerr() {
  case $1 in
    7) printf "Failed to connect() to host or proxy." ;;
    *) printf "CURL return %s" "$1" ;;
  esac
}

health_check() {
  if [ "$HEALTH_CHECK" = "1" ]; then
    echo "Health check disabled"
    return
  fi
  exp_time=0
  echo "Health checking ${HEALTH_CHECK_URL}"
  while true; do
    start-step "$exp_time."
    if status_code=$(/usr/bin/curl -L -o /dev/null --connect-timeout 5 -s -w "%{http_code}" "${HEALTH_CHECK_URL}"); then
      append-step " Http respond $status_code"
      for code in "${HEALTH_HTTP_CODE[@]}"
      do
        if [ "$status_code" == "$code" ]; then
          break 2
        fi
      done
    else
      append-step " $(curlerr $?)"
    fi

    sleep 1
    ((exp_time++))

    if [ "$exp_time" -gt ${APP_START_TIMEOUT} ]; then
      finish-step "App start failed. try tail application log."
      tail ${APP_LOG}
      exit 2
    fi
  done
  finish-step "Health check ${HEALTH_CHECK_URL} success."
}

print-info() {
  echo "Working Directory: $(pwd)"
  echo "Using:"
  echo "  nohup: $NOHUP"
  echo "  java:  $JAVA"
  echo "  opts:  ${JVM_OPTS}"
  echo "  jar:   ${JAR_PATH}"
  echo "  args:  ${JAR_ARGS}"
}

start_application() {
  query_java_pid
  if [ "$CURR_PID" = "" ]
  then
    if [ ! -f "$JAR_PATH" ]; then
      echo "There is no file \"$JAR_PATH\" ($(pwd))" >&2
      exit 44
    fi
    cd "$APP_HOME"
    print-info | tee "${APP_HOME}/version.info"
    ${NOHUP} ${JAVA} ${JVM_OPTS} -jar ${JAR_PATH} ${JAR_ARGS} >${STD_OUT} 2>&1 &
    local PID=$!
    local NOHUP_RET=$?
    local RET=99
    if [ "$NOHUP_RET" = "0" ]; then
      echo "Run nohup succeed (NOHUP RETURN: $NOHUP_RET, APP PID: $PID)"
      echo "$PID" > $PID_PATH
      echo "Wait 1 second."
      sleep 1
      if [ ! -d "/proc/$PID" ]; then
        wait "$PID"
        RET=$?
        echo "ERROR: Run app fail. Return: $RET"
        exit 4
      fi
    else
      echo "ERROR: Run jar failed with ($NOHUP_RET)"
      exit 3
    fi
  else
    echo "Running in $CURR_PID"
    OTHER_RUNNING=true
  fi
}

debug() {
  [ "$DEBUG" = "1" ] && echo $1
}

query_java_pid() {
  CURR_PID=
  if [ -f "$PID_PATH" ]; then
    pid=$(cat "$PID_PATH")
    debug "Using ${PID_PATH}. Got ${pid}"
    if ps $pid > /dev/null
    then
      CURR_PID="$pid"
    fi
  fi
  if [ "$CURR_PID" = "" ]
  then
    target=${JAR_PATH}
    debug "Using ${PGREP} -f '${target}' | grep -v '$$'"
    CURR_PID=$(${PGREP} -f "${target}" | grep -v "$$")
  fi
}

stop_application() {
  query_java_pid

  if [[ ! $CURR_PID ]]; then
    echo "No java process!"
    return
  fi

  echo "Stopping java process ($CURR_PID)."
  times="$APP_START_TIMEOUT"
  for e in $(seq $times); do
    sleep 1
    COST_TIME=$((times - e))
    if ps "$CURR_PID" > /dev/null
    then
      kill "$CURR_PID"
      print-step "Stopping java lasts $COST_TIME seconds."
    else
      finish-step "Java process has exited. Remove PID \"$PID_PATH\""
      rm "$PID_PATH" > /dev/null
      return
    fi
  done
  finish-step "Java process failed exit. Still running in $CURR_PID"
  exit 4
}

start() {
  start_application
  if [ "$OTHER_RUNNING" = false ]
  then
    health_check
  fi
}

stop() {
  stop_application
}

case "$ACTION" in
s|start)
  start
  ;;
t|stop)
  stop
  ;;
r|restart)
  stop
  start
  ;;
p|pid)
  query_java_pid
  ps -wwfp "$CURR_PID"
  ;;
c|check)
  health_check
  ;;
*)
  usage
  exit 1
  ;;
esac
