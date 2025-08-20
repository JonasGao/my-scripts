#!/bin/bash

function log () {
  echo "> [$(date)] $1"
}

if [ ! -e './app.war' ]; then
  log "[app.war] not found"
  exit 1
fi

if [ -e ./pid ]; then
  PREV_PID=$(cat pid)
  if [ -n "$PREV_PID" ] && [ $(ps -p $PREV_PID -o pid=) == "$PREV_PID" ]; then
    log "kill $PREV_PID"
    kill $PREV_PID
    KILL_CHECK_COUNT=0
    while [ "$(ps -p $PREV_PID -o pid=)" == "$PREV_PID" ];
    do
      if (( KILL_CHECK_COUNT > 4 )); then
        log "kill fail!"
        exit 1
      fi
      KILL_COUNT=$(expr $KILL_COUNT + 1)
      log "check kill 第 $KILL_COUNT 次"
      sleep 1
    done
  fi
fi

log "clear prev files"
rm -rf WEB-INF META-INF
log "unzip"
unzip app.war > unzip_output
cp application-datasource.yml WEB-INF/classes
cd WEB-INF
log "run java"
nohup java -classpath "lib/*:classes/." com.example.MainApplication >> ../output 2>&1 &
cd ..
echo $! > pid
log "running in $(cat pid)"
