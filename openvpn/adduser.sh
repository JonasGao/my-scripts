#!/bin/bash
#
# OpenVPN adduser helper script
# Version: 1.1.0
# Author: your-name
# Description: Generate OpenVPN client certificates for a given username and
#              package them into a .tar.gz under the user's HOME directory.
#              Run with -h/--help for usage.

# ---- Color & logging helpers ----
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
NC="\033[0m"

log_info() {
    echo -e "[INFO] ${GREEN}$*${NC}"
}

log_warn() {
    echo -e "[WARN] ${YELLOW}$*${NC}"
}

log_error() {
    echo -e "[ERROR] ${RED}$*${NC}"
}

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
    echo "选项:"
    echo "  -h, --help    显示此帮助并退出"
    echo
    echo "示例:"
    echo "  $cmd goodman"
    echo
    echo "执行后将在 \$HOME 目录生成 goodman.tar.gz，内含 goodman.csr、goodman.key、goodman.crt。"
}

# -- help support --
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    usage
    exit 0
fi

[ -z "$1" ] && usage && exit 1

USERNAME="$1"

# 用户名合法性校验：仅允许字母、数字、下划线、连字符，长度 1-64
if ! echo "$USERNAME" | grep -Eq '^[A-Za-z0-9_-]{1,64}$'; then
    log_error "用户名不合法：仅允许字母、数字、下划线、连字符，长度 1-64。"
    exit 1
fi

TAR_NAME="$USERNAME.tar.gz"
log_info "开始为用户 $USERNAME 生成 openvpn 证书..."
pushd /usr/share/doc/openvpn-2.2.2/easy-rsa/2.0/ || exit 2
log_info "加载 easy-rsa 环境变量..."
source ./vars

# 在生成之前检查是否已存在同名证书文件，避免覆盖
if [ -e "keys/$USERNAME.key" ] || [ -e "keys/$USERNAME.crt" ] || [ -e "keys/$USERNAME.csr" ]; then
    log_error "同名证书文件已存在：keys/$USERNAME.(key|crt|csr)。为避免覆盖，请更换用户名或手动清理后重试。"
    popd >/dev/null 2>&1 || true
    exit 4
fi

log_info "执行 build-key $USERNAME ..."
if ! ./build-key "$USERNAME"; then
    log_error "build-key 执行失败。"
    popd >/dev/null 2>&1 || true
    exit 5
fi

log_info "进入 keys 目录..."
cd keys || exit 2

log_info "打包证书文件 -> $TAR_NAME ..."
if ! tar -cvzf "$TAR_NAME" "$USERNAME.csr" "$USERNAME.key" "$USERNAME.crt"; then
    log_error "打包失败。"
    popd >/dev/null 2>&1 || true
    exit 6
fi

log_info "移动 $TAR_NAME 到 $HOME/ ..."
if ! mv "$TAR_NAME" "$HOME/"; then
    log_error "移动压缩包失败。"
    popd >/dev/null 2>&1 || true
    exit 7
fi

popd || exit 3
log_info "用户 $USERNAME 证书生成完毕，已打包至 $HOME/$TAR_NAME"

# 清理提示
log_warn "清理提示：如果已安全保存 $HOME/$TAR_NAME，可按需清理服务器上的中间/输出文件："
echo "  rm -f /usr/share/doc/openvpn-2.2.2/easy-rsa/2.0/keys/$USERNAME.{csr,crt,key}"
