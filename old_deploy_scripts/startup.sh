#!/bin/bash

if [ ! -e './app.jar' ]; then
  echo "[app.jar] not found"
  exit 1
fi

if [ -e ./pid ]; then
  PREV_PID=$(cat pid)
  if [ -n "$PREV_PID" ] && [ $(ps -p $PREV_PID -o pid=) == "$PREV_PID" ]; then
    echo "> [$(date +%H:%M:%S)] kill $PREV_PID"
    kill $PREV_PID
    KILL_CHECK_COUNT=0
    while [ "$(ps -p $PREV_PID -o pid=)" == "$PREV_PID" ];
    do
      if (( KILL_CHECK_COUNT > 4 )); then
        echo "> [$(date +%H:%M:%S)] kill fail!"
        exit 1
      fi
      KILL_COUNT=$(expr $KILL_COUNT + 1)
      echo "> [$(date +%H:%M:%S)] check kill 第 $KILL_COUNT 次"
      sleep 1
    done
  fi
fi

echo "> [$(date +%H:%M:%S)] run app.jar"
nohup java -jar app.jar >> ./output 2>&1 &
echo $! > pid
echo "> [$(date +%H:%M:%S)] running in $(cat pid)"
