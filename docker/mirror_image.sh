#!/bin/bash

# -------------------------------------------------------------
# 脚本名称: mirror_image.sh
# 功能概述:
#   从多个代理源依次尝试拉取指定 Docker 镜像，
#   拉取成功后重标记为本地私有仓库地址并推送。
#
# 使用方法:
#   ./mirror_image.sh <image[:tag]>
#
# 参数说明:
#   位置参数 SOURCE_IMAGE 为镜像名称（可含命名空间与 tag）
#
# 关键变量（可在执行前导出以覆盖）:
#   DEST_REGISTRY   目标私有仓库地址，默认 127.0.0.1:5000
#   PROXY_FILE      代理列表文件，默认 $HOME/.docker-hub-proxy
#
# 代理文件格式:
#   - 文本文件，每行一个代理前缀，例如：
#       registry-1.docker.io
#       hub-mirror.example.com
#   - 支持空行与以 # 开头的注释行
#
# 依赖项:
#   - docker 必需
#
# 适用场景:
#   - 本地拉取官方镜像较慢或受限时，从自有/第三方代理源镜像加速
#   - 将公共镜像快速同步到私有仓库
#
# 示例:
#   ./mirror_image.sh redis:7-alpine
#   ./mirror_image.sh apache/doris:be-3.1
#
# 退出码:
#   0 表示镜像推送成功；非 0 表示失败（包括全部代理拉取失败、标记或推送失败）
# -------------------------------------------------------------

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
    