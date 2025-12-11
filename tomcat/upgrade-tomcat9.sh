#!/bin/bash
TARGET="$1"
BACKUP_NAME="$2"
TOMCAT="apache-tomcat-9.0.74"
TOMCAT_TAR="${TOMCAT}.tar.gz"

# Prepare new tomcat.
if [ ! -d "$TOMCAT" ]; then
  if [ ! -f "$TOMCAT_TAR" ]; then
    wget "https://dlcdn.apache.org/tomcat/tomcat-9/v9.0.74/bin/$TOMCAT_TAR" --no-check-certificate
  fi
  if [ -f "$TOMCAT_TAR" ]; then
    tar -xvf apache-tomcat-9.0.74.tar.gz
  else
    echo "Download tomcat tar fail!"
    exit 1
  fi
fi

# Check parameters and target exists ...
if [ "$TARGET" = "" ]; then
  echo "No Target! Parameter 1."
  exit 2
fi
if [ ! -d "$TARGET" ]; then
  echo "Target not exists or not dir"
  exit 3
fi

# Check backup parameters and backup target
if [ "$BACKUP_NAME" = "" ]; then
  echo "No Backup name! Parameter 2."
  exit 4
fi
if [ -d "$BACKUP_NAME" ]; then
  echo "Backup exists!"
  exit 5
fi
echo "Backuping \"$TARGET\" to \"./$BACKUP_NAME\""
cp -r "$TARGET" "./$BACKUP_NAME"

# Replace lib
cp -rav $TOMCAT/lib/* $TARGET/lib/
cp -rav $TOMCAT/bin/* $TARGET/bin/