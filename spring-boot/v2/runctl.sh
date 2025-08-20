#!/bin/bash

CWD=$(pwd)
PROG=$0
PROG_DIR=$(dirname $PROG)
PROG_NAME=$(basename $PROG)
TARGET_APP="simphook"
WD="${PROG_DIR}"

APP="${WD}/${TARGET_APP}"
ACTION=$1
PIDF="pid"
NOHUP=$(which nohup 2>/dev/null)
PGREP=$(which pgrep 2>/dev/null)
CURR_PID=
STD_OUTF="${WD}/app.log"

usage() {
  printf """Usage: $PROG_NAME <command>
There are some commands:
  s, start
  t, stop
  r, restart
  p, pid
"""
}

debug() {
  [ "$DEBUG" = "1" ] && echo "[DEBUG]" $@
}

set_pid() {
  CURR_PID=
  if [ -f "$PIDF" ]; then
    pid=$(cat "$PIDF")
    debug "Using ${PIDF}. Got ${pid}"
    if ps $pid > /dev/null
    then
      CURR_PID="$pid"
    fi
  fi
  if [ "$CURR_PID" = "" ]
  then
    debug "Using ${PGREP} -f '${TARGET_APP}' | grep -v '$$'"
    CURR_PID=$(${PGREP} -f "${TARGET_APP}" | grep -v "$$")
  fi
}

run_app() {
  set_pid
  if [ "$CURR_PID" = "" ]
  then
    echo "Run (${APP})"
    ${NOHUP} ${APP} >${STD_OUTF} 2>&1 &
    pid=$!
    rc=$?
    if [ "$rc" = "0" ]; then
      echo "Run succeed ($pid)"
      echo "$pid" > $PIDF
    else
      echo "Run failed with ($rc)"
      exit 3
    fi
  else
    echo "Running in $CURR_PID"
  fi
}

stop_app() {
  set_pid
  if [[ ! $CURR_PID ]]; then
    echo "No ${TARGET_APP} process!"
    return
  fi
  echo "Stopping... process"
  if ps $CURR_PID > /dev/null
  then
    kill "$CURR_PID"
    echo -e "Stopping.."
  fi
}

start() {
  run_app
}

stop() {
  stop_app
}

case "$ACTION" in
s|start)
  start
  ;;
t|stop)
  stop
  ;;
p|pid)
  set_pid
  echo "Current running in $CURR_PID"
  ;;
*)
  usage
  exit 1
  ;;
esac
