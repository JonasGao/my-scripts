#!/bin/bash

# install:
#   cp docker-ip.sh /usr/libexec/docker/cli-plugins/docker-ip
#   chmod +x /usr/libexec/docker/cli-plugins/docker-ip

# 新增：处理 Docker CLI 插件元数据请求
if [ "$1" = "docker-cli-plugin-metadata" ]; then
    cat <<EOF
{
  "SchemaVersion": "0.1.0",
  "Vendor": "Custom",
  "Version": "0.1.0",
  "ShortDescription": "Query container IP addresses",
  "Name": "ip"
}
EOF
    exit 0
fi

# 1. 检查是否传入容器名/ID（参数个数判断）
if [ $# -eq 0 ]; then
    echo "用法：docker ip <容器名或容器ID> [多个容器名/ID用空格分隔]"
    echo "示例：docker ip my-container"
    echo "      docker ip 1a2b3c4d5e6f my-nginx"
    exit 1
fi

# 2. 遍历所有传入的容器，逐个查询IP
for CONTAINER in "$@"; do
    # 跳过Docker CLI插件调用参数
    if [ "$CONTAINER" = "ip" ]; then
        continue
    fi
    
    echo "=== 容器: $CONTAINER ==="
    
    # 2.1 检查容器是否存在（避免无效容器名/ID）
    if ! docker inspect "$CONTAINER" >/dev/null 2>&1; then
        echo "错误：容器 '$CONTAINER' 不存在或未运行（需确保容器已创建）"
        echo ""
        continue
    fi

    # 2.2 提取容器的所有网络IP（支持多网络场景）
    # 使用docker inspect + Go模板，提取每个网络的"网络名:IP"
    # 简化输出，只显示IPv4地址
    IP_INFO=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}} {{end}}' "$CONTAINER")

    # 2.3 处理IP为空的情况（如容器未连接任何网络）
    if [ -z "$IP_INFO" ]; then
        echo "未获取到IP：容器未连接任何Docker网络（可通过 'docker network connect' 连接网络）"
    else
        echo "IP地址列表："
        echo "$IP_INFO" | awk '{print "  - " $0}'  # 格式化输出，加列表前缀
    fi

    echo ""  # 每个容器结果之间空行分隔
done