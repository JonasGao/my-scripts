#!/bin/bash

set -e

DOMAIN_KEY="example.cn"

# 1. Request cert by acme.sh
#    Copy cert and key files to acme_target directory after issued.

TARGET_PREFIX=$(date +%Y%m%d)
TARGET_NAME="${DOMAIN_KEY}_${TARGET_PREFIX}"
TAR_NAME="${TARGET_NAME}.tgz"
TARGET_DIR="/root/acme_target/${TARGET_NAME}"
TARGET_TAR="/root/acme_target/${TAR_NAME}"

mkdir -p "$TARGET_DIR"

/root/.acme.sh/acme.sh --issue --dns dns_ali -d example.com -d *.example.com --server letsencrypt

echo "After issue, copy cert and key files"

cp "/root/.acme.sh/example.com/test.madmod.cn.cer" "$TARGET_DIR/cer"
cp "/root/.acme.sh/example.com/test.madmod.cn.key" "$TARGET_DIR/key"
cp "/root/.acme.sh/example.com/ca.cer"             "$TARGET_DIR/ca"
cp "/root/.acme.sh/example.com/fullchain.cer"      "$TARGET_DIR/chain"

# 2. Tar the cert and key files.
#    Then clear target dir

echo "Tar files and move"

tar -cvzf "$TARGET_TAR" -C "$TARGET_DIR" .
rm -rf "$TARGET_DIR"

# 3. Deploy the cert and key files to 172.16.0.47 nginx
#    Location like /etc/pki/nginx/240207_3m/test.madmod.cn

echo "Deploy and link remote"

NGINX_SERVER="172.16.0.1"
PKI_HOME="/etc/pki/nginx"
SERVER_USER="deployer"
PKI_DIR="${PKI_HOME}/${TARGET_PREFIX}_3m/${DOMAIN_KEY}"

ssh "${SERVER_USER}@${NGINX_SERVER}" "mkdir -p ${PKI_DIR}"
scp "$TARGET_TAR" "${SERVER_USER}@${NGINX_SERVER}:${PKI_DIR}"
ssh "${SERVER_USER}@${NGINX_SERVER}" "cd ${PKI_DIR} && tar -xvf ${TAR_NAME} && ln-pki ${TARGET_PREFIX}_3m ${DOMAIN_KEY}"