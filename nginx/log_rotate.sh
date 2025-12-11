#!/bin/bash
cd /usr/local/nginx/logs
PID=$(cat nginx.pid)
DATE=$(date +%Y%m%d)
LOG="access.log"
FILE="$LOG.$DATE"
GZ="${FILE}.gz"
echo "Working in $(pwd), PID: $PID"
[ -f $GZ ] && echo "\"$GZ\" already exists, skip." && exit 1
mv $LOG $FILE
echo "Moved to $FILE, will reload logging"
kill -USR1 `cat nginx.pid`
sleep 1
echo "Gzip $FILE"
gzip $FILE
echo "Finish"