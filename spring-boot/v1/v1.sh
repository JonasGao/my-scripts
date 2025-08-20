#!/bin/bash

cd $1
echo "> [$(date +%H:%M:%S)] cd [$1]"

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
      sleep 2
    done
  fi
fi

if [ -e "output" ]; then
  echo "> [$(date +%H:%M:%S)] backup log"
  mv output output.latest
else
  echo "> [$(date +%H:%M:%S)] no output"
fi

if [ "$2" = "quit" ]; then
  exit 0
fi

echo "> [$(date +%H:%M:%S)] run"
nohup mvn spring-boot:run > ./output 2>&1 &
echo $! > pid
echo "> [$(date +%H:%M:%S)] running in $(cat pid)"
