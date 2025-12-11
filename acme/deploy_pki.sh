#!/bin/bash

TARGET_DOMAIN="$1"
TARGET_TAR="$2"
EXPIRE="$3"

[ "$TARGET_DOMAIN" = "" ] && echo "Missing Parameter 1: domain" && exit 1
[ "$TARGET_TAR" = "" ] && echo "Missing Parameter 2: pki tar" && exit 2
[ ! -f "$TARGET_TAR" ] && echo "Parameter 2: pki tar is not a file" && exit 3
[ "$EXPIRE" = "" ] && EXPIRE="3m" && echo "INFO: Default setup expire 3m"

DATE=`date +%y%m%d`
PKI_HOME="/etc/pki/nginx"
PKI_PARENT_DIR_NAME="${DATE}_${EXPIRE}"
PKI_DIR_BASE="$PKI_HOME/$PKI_PARENT_DIR_NAME"
PKI_DIR_FULL_PATH="$PKI_DIR_BASE/$TARGET_DOMAIN"
PKI_TAR="pki.tar"

mkdir -p "$PKI_DIR_FULL_PATH"
echo "Create dir: $PKI_DIR_FULL_PATH"
mv "$TARGET_TAR" "$PKI_DIR_FULL_PATH/$PKI_TAR"
echo "Moved \"$TARGET_TAR\" to \"$PKI_DIR_FULL_PATH/$PKI_TAR\""
tar -xvf "$PKI_DIR_FULL_PATH/$PKI_TAR" -C $PKI_DIR_FULL_PATH
echo "Expanded tar \"$PKI_DIR_FULL_PATH/$PKI_TAR\" with \"$PKI_DIR_FULL_PATH\""
ln -vfns "$PKI_DIR_FULL_PATH/chain" "$PKI_HOME/${TARGET_DOMAIN}.cer"
ln -vfns "$PKI_DIR_FULL_PATH/key" "$PKI_HOME/private/${TARGET_DOMAIN}.key"
echo "Finish linking cer and key file"