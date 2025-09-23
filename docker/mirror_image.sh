#!/bin/bash

# 检查入参是否正确
if [ $# -ne 1 ]; then
    echo "使用方法: $0 <镜像名称>"
    echo "示例: $0 redis:7-alpine 或 $0 apache/doris:be-3.1"
    exit 1
fi

# 配置参数
SOURCE_IMAGE="$1"
DEST_REGISTRY="127.0.0.1:5000"
PROXY_FILE="$HOME/.docker-hub-proxy"
DEST_IMAGE="${DEST_REGISTRY}/${SOURCE_IMAGE}"

# 检查代理文件是否存在
if [ ! -f "$PROXY_FILE" ]; then
    echo "错误: 代理文件 $PROXY_FILE 不存在"
    exit 1
fi

# 读取代理列表并尝试拉取镜像
while IFS= read -r proxy; do
    # 跳过空行和注释行
    if [ -z "$proxy" ] || [[ "$proxy" =~ ^# ]]; then
        continue
    fi

    echo "尝试使用代理: $proxy"
    PROXY_IMAGE="${proxy}/${SOURCE_IMAGE}"
    
    # 尝试拉取镜像
    if docker pull "$PROXY_IMAGE"; then
        echo "成功拉取镜像: $PROXY_IMAGE"
        
        # 标记镜像
        echo "正在标记镜像为: $DEST_IMAGE"
        if docker tag "$PROXY_IMAGE" "$DEST_IMAGE"; then
            # 推送镜像到目标仓库
            echo "正在推送镜像到: $DEST_REGISTRY"
            if docker push "$DEST_IMAGE"; then
                echo "镜像推送成功!"
                echo "你可以使用以下镜像名称: $DEST_IMAGE"
                exit 0
            else
                echo "推送镜像失败"
                exit 1
            fi
        else
            echo "标记镜像失败"
            exit 1
        fi
    else
        echo "使用代理 $proxy 拉取镜像失败，尝试下一个代理..."
    fi
done < "$PROXY_FILE"

# 如果所有代理都失败
echo "错误: 所有代理均无法拉取镜像 $SOURCE_IMAGE"
exit 1
    