#!/bin/bash

# 使用 request.txt 作为模板，调用 sign.sh 生成新证书
# 用法: ./gen-cert.sh <主域名> [DNS.2] [DNS.3] ...

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REQUEST_TEMPLATE="${SCRIPT_DIR}/request.txt"
SIGN_SCRIPT="${SCRIPT_DIR}/sign.sh"

# 检查模板和 sign 脚本是否存在
if [ ! -f "$REQUEST_TEMPLATE" ]; then
    echo "错误: 请求模板 $REQUEST_TEMPLATE 不存在"
    exit 1
fi

if [ ! -f "$SIGN_SCRIPT" ]; then
    echo "错误: 签名脚本 $SIGN_SCRIPT 不存在"
    exit 1
fi

# 检查参数
if [ -z "$1" ]; then
    echo "用法: $0 <主域名> [DNS.2] [DNS.3] ..."
    echo "示例: $0 harbor.my"
    echo "示例: $0 harbor.my registry.harbor.my"
    exit 1
fi

MAIN_CN="$1"
shift
EXTRA_DNS=("$@")

# 域名目录：使用主 CN 作为目录名，放在当前目录下
DOMAIN_DIR="${SCRIPT_DIR}/${MAIN_CN}"
REQUEST_FILE="${DOMAIN_DIR}/request"

# 若目录已存在且已有 request，可选跳过；这里总是重建 request 并执行 sign
mkdir -p "$DOMAIN_DIR"

# 从模板生成 request 文件，替换占位符 {{DOMAIN}}，并追加可选 DNS.2、DNS.3...
echo "正在根据 request.txt 生成请求配置: $REQUEST_FILE"
i=2
while IFS= read -r line; do
    # 替换模板中的 {{DOMAIN}} 为主域名
    line="${line//\{\{DOMAIN\}\}/${MAIN_CN}}"
    echo "$line"
    # 在 DNS.1 行之后插入额外 DNS
    if [[ "$line" =~ ^DNS\.1[[:space:]]*= ]]; then
        for dns in "${EXTRA_DNS[@]}"; do
            echo "DNS.${i} = ${dns}"
            (( i++ )) || true
        done
    fi
done < "$REQUEST_TEMPLATE" > "$REQUEST_FILE"

# 调用 sign.sh 生成证书
echo "正在调用 sign.sh 生成证书..."
"$SIGN_SCRIPT" "$DOMAIN_DIR"

echo ""
echo "全部完成。证书目录: $DOMAIN_DIR"
