#!/bin/bash

# Example:
# 
# Get logger level
# ./boot-logger.sh org.springframework.data.mongodb.core.MongoTemplate get
# or
# APP_PORT=8182 ./boot-logger.sh org.springframework.data.mongodb.core.MongoTemplate get
#
# Set logger level
# ./boot-logger.sh org.springframework.data.mongodb.core.MongoTemplate set INFO

usage()
{
  echo "Usage: $0 <logger_name> <get|set> [set_level]"
  exit 2
}

unset ACTION LOGGER LEVEL

LOGGER=$1
ACTION=$2
LEVEL=$3

[ -z "$APP_HOST" ] && APP_HOST="127.0.0.1"
[ -z "$APP_PORT" ] && APP_PORT="8080"
[ -z "$ACTION" ] && usage
[ -z "$LOGGER" ] && usage

APP_DOMAIN="$APP_HOST:$APP_PORT"

get_logger()
{
  echo "Getting: $LOGGER"
  #curl -sw '\n' http://$APP_DOMAIN/actuator/loggers/$LOGGER | python -m json.tool
  curl -sw '\n' http://$APP_DOMAIN/actuator/loggers/$LOGGER | jq .
}

set_logger()
{
  echo "Setting: $LOGGER"
  echo "  => ${LEVEL:-NULL}"
  curl -w '\n' -X POST \
    -H 'Content-Type: application/json' \
    -d "{\"configuredLevel\": \"${LEVEL}\"}" \
    http://$APP_DOMAIN/actuator/loggers/${LOGGER}
}

case $ACTION in
  set) set_logger ;;
  get) get_logger ;;
  ?) usage ;;
esac