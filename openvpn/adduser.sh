#!/bin/bash

function usage() {
    local cmd
    cmd=$(basename "$0")
    echo "用法: $cmd <username>"
    echo
    echo "说明:"
    echo "  本脚本用于为 OpenVPN 新用户生成证书，并将相关文件打包至用户主目录。"
    echo
    echo "参数:"
    echo "  <username>    新用户的用户名，证书文件将以该用户名命名。"
    echo
    echo "示例:"
    echo "  $cmd goodman"
    echo
    echo "执行后将在 \$HOME 目录生成 goodman.tar.gz，内含 goodman.csr、goodman.key、goodman.crt。"
}

[ -z "$1" ] && usage && exit 1

USERNAME="$1"
TAR_NAME="$USERNAME.tar.gz"
echo "[INFO] 开始为用户 $USERNAME 生成 openvpn 证书..."
pushd /usr/share/doc/openvpn-2.2.2/easy-rsa/2.0/ || exit 2
echo "[INFO] 加载 easy-rsa 环境变量..."
source ./vars
echo "[INFO] 执行 build-key $USERNAME ..."
./build-key "$USERNAME"
echo "[INFO] 进入 keys 目录..."
cd keys || exit 2
echo "[INFO] 打包证书文件: $USERNAME.csr $USERNAME.key $USERNAME.crt -> $TAR_NAME ..."
tar -cvzf "$TAR_NAME" "$USERNAME.csr" "$USERNAME.key" "$USERNAME.crt"
echo "[INFO] 移动 $TAR_NAME 到 $HOME/ ..."
mv "$TAR_NAME" "$HOME/"
popd "$HOME" || exit 3
echo "[INFO] 用户 $USERNAME 证书生成完毕，已打包至 $HOME/$TAR_NAME"
