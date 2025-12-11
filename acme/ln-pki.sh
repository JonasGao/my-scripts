#!/bin/bash

# Directory structure
# ─ /etc/pki/nginx
#   ├─ 20231204_3m
#   │  └─ example.com
#   │     ├─ chain
#   │     └─ key
#   ├─ example.com.cer --> 20231204_3m/example.com/chain
#   └─ private
#      └─ example.com.key --> ../20231204_3m/example.com/key

PKI_HOME="/etc/pki/nginx"
PARENT="$1"
DOMAIN="$2"

[ -z "$PARENT" ] && echo "Missing Parameter 1: Pki base dir, some thing like 20240304_3m under ${PKI_HOME}" && exit 1
[ -z "$DOMAIN" ] && echo "Missing Parameter 2: Domain key, like example.com" && exit 2

PKI_DIR="${PARENT}/${DOMAIN}"

function link {
  cd "$PKI_HOME" || exit 3
  echo "Into ${PKI_HOME}"
  echo "Will link ${PKI_DIR}"
  ln -vfns "${PKI_DIR}/chain" "${DOMAIN}.cer"
  ln -vfns "../${PKI_DIR}/key" "private/${DOMAIN}.key"
  echo "Finish linking cer and key file"
}

link