#!/bin/bash
cd workspace
../mvnw clean package
echo '> [$(date)] scp upload jar'
scp target/app.jar username@host:~/remote-workspace/app.jar
sleep 1
echo '> [$(date)] ssh run startup'
ssh username@host "remote-workspace/startup.sh"