#!/bin/bash

# Set strict mode - exit on error and undefined variables
set -euo pipefail

APP_NAME="${1}"
# Check if DEPLOY_DIR is set and not empty
if [[ -z "${DEPLOY_DIR}" ]]; then
    echo "Error: DEPLOY_DIR is not set or is empty"
    exit 1
fi

# Define variables for better readability and maintainability
APP_DIR="${APP_DIR:-${DEPLOY_DIR}/${APP_NAME}}"
PACKAGE_FILE="${PACKAGE_FILE:-package.tgz}"
JAR_FILE="${JAR_FILE:-${APP_NAME}.jar}"
TARGET_JAR="${TARGET_JAR:-app.jar}"

# Create directory if it doesn't exist
mkdir -p "${APP_DIR}"

# Change to app directory
cd "${APP_DIR}" || exit 1

# Check if package file exists before extraction
if [[ -f "${PACKAGE_FILE}" ]]; then
    tar -xvf "${PACKAGE_FILE}"
else
    echo "Error: Package file ${PACKAGE_FILE} not found in ${APP_DIR}"
    exit 1
fi

# Check if jar file exists before moving
if [[ -f "${JAR_FILE}" ]]; then
    mv "${JAR_FILE}" "${TARGET_JAR}"
else
    echo "Error: JAR file ${JAR_FILE} not found in ${APP_DIR}"
    exit 1
fi

# Change back to retail directory
cd "${DEPLOY_DIR}" || exit 1

# Check if STAGING variable equals "是" and set SPRING_APPLICATION_JSON accordingly
if [[ "${STAGING:-}" == "是" ]]; then
    export SPRING_APPLICATION_JSON='{"spring.profiles.active":"staging"}'
fi

# Check if servicectl exists and is executable (local or global)
if [[ -x "./servicectl" ]]; then
    ./servicectl d "${APP_NAME}"
elif command -v servicectl &>/dev/null && [[ -x "$(command -v servicectl)" ]]; then
    servicectl d "${APP_NAME}"
else
    echo "Error: servicectl not found or not executable (neither local nor global)"
    exit 1
fi

echo "Deployment completed successfully for ${APP_NAME}"
