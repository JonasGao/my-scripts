#!/bin/bash

TARGET_DIR=$1
PORT=$2

echo "enter $TARGET_DIR"
cd $TARGET_DIR

if [ -e pid ]; then
  PREV_PID=$(cat pid)
  if [ -n "$PREV_PID" ]; then
    PREV_PS=$(ps --no-headers $PREV_PID)
    if [ -n "$PREV_PS" ]; then
      echo "kill prev pid: $PREV_PID"
      kill $PREV_PID
    fi
  fi
fi

echo "clear prev files"
rm -rf WEB-INF META-INF
echo "upzip"
unzip app-1.0-SNAPSHOT.war > unzip_output
# cp application-datasource.yml WEB-INF/classes
# if [ -n "$PORT" ]; then
#   export SPRING_APPLICATION_JSON='{"server":{"port":$PORT}}'
# fi
cd WEB-INF
echo "run java"
nohup java -classpath "lib/*:classes/." com.example.Application >> ../output 2>&1 &
cd ..
echo $! > pid
echo "running in $(cat pid)"