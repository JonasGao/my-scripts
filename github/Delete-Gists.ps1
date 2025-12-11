#!/usr/bin/env pwsh

<#
.SYNOPSIS
删除 GitHub Gist

.DESCRIPTION
根据指定文件中的 Gist ID 列表，调用 GitHub API 删除对应的 Gist

.PARAMETER Token
GitHub Token，用于认证 API 请求

.PARAMETER FilePath
包含 Gist ID 列表的文件路径，默认值为 gist_id_list

.EXAMPLE
.\Delete-Gists.ps1 -Token "your_github_token" -FilePath "gist_ids.txt"

.EXAMPLE
.\Delete-Gists.ps1 -Token "your_github_token"
#>

param(
    [Parameter(Mandatory = $true, HelpMessage = "GitHub Token")]
    [string]$Token,
    
    [Parameter(HelpMessage = "Gist ID 列表文件路径")]
    [string]$FilePath = "gist_id_list"
)

# 检查文件是否存在
if (-not (Test-Path $FilePath)) {
    Write-Error "文件 $FilePath 不存在"
    exit 1
}

# 读取 Gist ID 列表
$gistIds = Get-Content $FilePath | Where-Object { $_ -match '^[0-9a-f]{32}$' }

if ($gistIds.Count -eq 0) {
    Write-Output "文件 $FilePath 中没有有效的 Gist ID"
    exit 0
}

Write-Output "开始删除 $($gistIds.Count) 个 Gist..."
Write-Output ("=" * 50)

# 设置 API 基本信息
$baseUrl = "https://api.github.com"
$headers = @{
    "Authorization" = "token $Token"
    "Accept" = "application/vnd.github.v3+json"
}

$successCount = 0
$failCount = 0

# 遍历删除每个 Gist
foreach ($gistId in $gistIds) {
    $url = "$baseUrl/gists/$gistId"
    
    try {
        $response = Invoke-RestMethod -Uri $url -Method Delete -Headers $headers
        Write-Output "✅ 成功删除 Gist: $gistId"
        $successCount++
    } catch {
        Write-Output "❌ 删除 Gist 失败: $gistId"
        Write-Output "   错误信息: $($_.Exception.Message)"
        $failCount++
    }
    
    # 避免 API 限流，添加短暂延迟
    Start-Sleep -Milliseconds 500
}

Write-Output ("=" * 50)
Write-Output "删除完成！"
Write-Output "成功: $successCount 个 Gist"
Write-Output "失败: $failCount 个 Gist"
Write-Output "总计: $($gistIds.Count) 个 Gist"
