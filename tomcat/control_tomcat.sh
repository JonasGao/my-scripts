#!/bin/bash
ACTION=$1
TOMCAT_HOME=$2
STARTUP_SH="startup.sh"
STOP_SH="shutdown.sh"
PORTER=$(which tomcat-porter 2>/dev/null)
HEALTH_HTTP_CODE=(200 404 403 405)
APP_START_TIMEOUT=30

[ -z "$ACTION" ] && echo "ERROR: Not found argument 1" && exit 1
[ -z "$TOMCAT_HOME" ] && echo "ERROR: Not found argument 2" && exit 2

usage() {
  printf """Usage: $PROG_NAME <command> <tomcat_home>
There are some commands:
  s, start
  t, stop
"""
}

kill_tomcat() {
  tomcat_name=$1
  pids=$(jps -lv | grep "$tomcat_name" | grep -v grep | cut -d " " -f 1)

  echo "$tomcat_name pid is $pids"

  if [ -z "$pids" ]; then
    echo "Not found pid or application already exit. 没有指定进程或已经正确停止。"
  else
    i=1
    while [ -n "$pids" ] && [ $i -le 3 ]; do
      for pid in $pids; do
        kill "$pid"
        echo "Killed $tomcat_name pid $pid. $i times"
      done
      sleep 1s
      pids=$(jps -lv | grep "$tomcat_name" | grep -v grep | cut -d " " -f 1)
      echo "After $i time killed, pids is: $pids"
      ((i++))
    done

    #此时依然存在
    pids=$(jps -lv | grep "$tomcat_name" | grep -v grep | cut -d " " -f 1)
    if [ -n "$pids" ]; then
      for pid in $pids; do
        echo "Force kill process $pid"
        kill -9 "$pid"
      done
    fi
    sleep 1s
    pids=$(jps -lv | grep "$tomcat_name" | grep -v grep | cut -d " " -f 1)
    if [ -n "$pids" ]; then
      echo "CAN NOT STOP THE PROCESSES: $pids !"
      exit 3
    fi
  fi
}

health-check() {
  if [ -z "$PORTER" ]; then
    echo "Skip health-check case not found tomcat-porter."
    exit 0
  fi
  PORT=$(tomcat-porter get "//Server/Service/Connector/@port" "$TOMCAT_HOME")
  if [ -z "$PORT" ]; then
    echo "Skip health-check case failure got port."
    exit 0
  fi
  exp_time=0
  HEALTH_CHECK_URL="http://127.0.0.1:$PORT"
  echo "Checking ${HEALTH_CHECK_URL}"
  while true; do
    if status_code=$(/usr/bin/curl -L -o /dev/null --connect-timeout 5 -s -w "%{http_code}" "${HEALTH_CHECK_URL}"); then
      printf "Status-code is %s. " "${status_code}"
      for code in ${HEALTH_HTTP_CODE[@]}; do
        if [ "$status_code" == "$code" ]; then
          echo "Health check ${HEALTH_CHECK_URL} success"
          break 2
        fi
      done
    else
      printf "curl return $?. "
    fi

    ((exp_time++))
    printf "Waiting to health check: %s..." $exp_time
    sleep 1
    printf "\r"

    if [ $exp_time -gt ${APP_START_TIMEOUT} ]; then
      echo 'App start failed.'
      exit 4
    fi
  done
}

case "$ACTION" in
s | start)
  "$TOMCAT_HOME/bin/$STARTUP_SH"
  sleep 1
  health-check
  ;;
t | stop)
  "$TOMCAT_HOME/bin/$STOP_SH"
  sleep 3
  kill_tomcat "$TOMCAT_HOME"
  ;;
*)
  usage
  ;;
esac