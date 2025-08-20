#!/bin/bash

TARGET_DIR=$1

function log () {
  echo -e "[$(date)] $@"
}

if [ -z "$TARGET_DIR" ]; then
  log "No dir option"
  exit 1
fi

if [ -d $TARGET_DIR ]; then
  log [$TARGET_DIR] already exists
else
  mkdir -p $TARGET_DIR
  MKDIR_RETURN=$?
  if [ "$MKDIR_RETURN" != 0 ]; then
    exit $MKDIR_RETURN
  fi
  # pre do something
  # cp application-datasource.yml $TARGET_DIR
  log [$TARGET_DIR] created
fi