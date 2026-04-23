#!/bin/bash

git rev-parse --git-dir > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "错误: 当前目录不是 git 仓库"
    exit 1
fi

if [ -n "$(git status --porcelain)" ]; then
    echo "错误: 工作区不干净，存在未提交的更改"
    git status --short
    exit 1
fi

current_branch=$(git rev-parse --abbrev-ref HEAD)
upstream=$(git rev-parse --abbrev-ref @{upstream} 2>/dev/null)

if [ -z "$upstream" ]; then
    echo "错误: 当前分支 '$current_branch' 没有设置上游分支"
    echo "提示: 使用 git push -u origin $current_branch 设置上游分支"
    exit 1
fi

unpushed=$(git log @{upstream}..HEAD --oneline 2>/dev/null)

if [ -z "$unpushed" ]; then
    echo "当前分支 '$current_branch' 已与远程同步，无需 push"
    exit 0
fi

echo "检测到以下未 push 的 commit:"
echo "$unpushed"
echo ""
echo "正在执行 push..."
git push

if [ $? -eq 0 ]; then
    echo "Push 成功"
else
    echo "Push 失败"
    exit 1
fi