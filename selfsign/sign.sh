#!/bin/bash

# 检查参数
if [ -z "$1" ]; then
        echo "错误: 请提供域名目录路径"
            echo "用法: $0 <域名目录>"
                exit 1
                fi

# 设置变量
WD="$1"
DM=$(basename "$WD")
SSL_SIZE="2048"
SSL_KEY="$WD/domain.key"
SSL_CONF="$WD/request"
SSL_CSR="$WD/domain.csr"
SSL_CERT="$WD/domain.pem"
SSL_CHAIN="$WD/chain"
CA_KEY="ca/ca.key"
CA_CERT="ca/ca.pem"
SSL_DATE="1365"

# 检查必要文件是否存在
if [ ! -f "$SSL_CONF" ]; then
        echo "错误: 配置文件 $SSL_CONF 不存在"
            exit 1
            fi

            if [ ! -f "$CA_KEY" ] || [ ! -f "$CA_CERT" ]; then
                    echo "错误: CA证书或密钥文件不存在"
                        exit 1
                        fi

                        echo "正在处理域名: $DM"

# 生成私钥
echo "生成私钥..."
openssl genrsa -out "${SSL_KEY}" "${SSL_SIZE}" || {
        echo "错误: 生成私钥失败"
            exit 1
}

# 生成证书签名请求
echo "生成证书签名请求..."
openssl req -sha256 -new -key "${SSL_KEY}" -out "${SSL_CSR}" -config "${SSL_CONF}" || {
        echo "错误: 生成CSR失败"
            exit 1
}

# 使用CA签名证书
echo "使用CA签名证书..."
openssl x509 -sha256 -req -in "${SSL_CSR}" -CA "${CA_CERT}" -CAkey "${CA_KEY}" \
    -CAcreateserial -out "${SSL_CERT}" -days "${SSL_DATE}" \
        -extensions v3_req -extfile "${SSL_CONF}" || {
                echo "错误: 证书签名失败"
                    exit 1
        }

# 生成证书链
echo "生成证书链..."
cat "${SSL_CERT}" > "${SSL_CHAIN}"
cat "${CA_CERT}" >> "${SSL_CHAIN}"

echo "证书生成完成！"
echo "证书文件位置:"
echo "- 私钥: ${SSL_KEY}"
echo "- 证书: ${SSL_CERT}"
echo "- 证书链: ${SSL_CHAIN}"
