#!/usr/bin/env pwsh

<#
.SYNOPSIS
    合并OpenVPN配置文件，将key、crt、ca文件内容合并到ovpn文件中

.DESCRIPTION
    根据提供的参数，将客户端key、证书和CA证书文件内容合并到OpenVPN配置文件中。
    使用XML标签格式：<key>、<cert>、<ca>来包装相应的内容。

.PARAMETER ConfigFile
    OpenVPN配置文件路径，默认为 client.ovpn

.PARAMETER KeyFile
    客户端key文件路径，默认为 client.key

.PARAMETER CertFile
    客户端证书文件路径，默认为 client.crt

.PARAMETER CaFile
    CA证书文件路径，默认为 ca.crt

.EXAMPLE
    .\merge-ovpn-config.ps1
    使用默认文件名合并配置文件

.EXAMPLE
    .\merge-ovpn-config.ps1 -ConfigFile "my-config.ovpn" -KeyFile "my-key.key" -CertFile "my-cert.crt" -CaFile "my-ca.crt"
    使用指定的文件名合并配置文件
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$ConfigFile = "client.ovpn",
    
    [Parameter(Mandatory = $false)]
    [string]$KeyFile = "client.key",
    
    [Parameter(Mandatory = $false)]
    [string]$CertFile = "client.crt",
    
    [Parameter(Mandatory = $false)]
    [string]$CaFile = "ca.crt"
)

# 函数：检查文件是否存在
function Test-FileExists {
    param([string]$FilePath, [string]$FileType)
    
    if (-not (Test-Path $FilePath)) {
        Write-Error "$FileType 文件不存在: $FilePath"
        return $false
    }
    return $true
}

# 函数：读取文件内容
function Get-FileContent {
    param([string]$FilePath)
    
    try {
        return Get-Content $FilePath -Raw -Encoding UTF8
    }
    catch {
        Write-Error "读取文件失败: $FilePath - $($_.Exception.Message)"
        return $null
    }
}

# 函数：确保配置中包含某行指令（若已存在同类指令则不追加）
function Add-DirectiveIfMissing {
    param(
        [string]$ConfigContent,
        [string]$DirectiveKey,
        [string]$DirectiveLine
    )

    # 将配置拆分为行，忽略以 # 或 ; 开头的注释行，仅匹配有效指令行
    $lines = $ConfigContent -split "`r?`n"
    $exists = $false
    foreach ($line in $lines) {
        $trim = $line.TrimStart()
        if ($trim -match '^(#|;)' ) { continue }
        if ($trim -imatch "^\Q$DirectiveKey\E\b") {
            $exists = $true
            break
        }
    }

    if ($exists) {
        Write-Host "已存在指令: $DirectiveKey，跳过追加" -ForegroundColor DarkYellow
        return $ConfigContent
    }

    Write-Host "追加指令: $DirectiveLine" -ForegroundColor DarkGreen
    return ($ConfigContent.TrimEnd() + "`n`n$DirectiveLine")
}

# 函数：合并文件内容到配置中
function Merge-FileToConfig {
    param(
        [string]$ConfigContent,
        [string]$FileContent,
        [string]$TagName,
        [string]$FileName
    )
    
    if ([string]::IsNullOrEmpty($FileContent)) {
        Write-Warning "文件内容为空: $FileName"
        return $ConfigContent
    }
    
    # 移除文件内容开头和结尾的空白字符
    $FileContent = $FileContent.Trim()
    
    # 构建标签内容
    $TagContent = "<$TagName>`n$FileContent`n</$TagName>"
    
    # 检查是否已存在XML标签格式
    $TagPattern = "<$TagName>[\s\S]*?</$TagName>"
    if ($ConfigContent -match $TagPattern) {
        # 如果XML标签存在，替换内容
        Write-Host "替换现有的 <$TagName> 标签内容"
        $ConfigContent = $ConfigContent -replace $TagPattern, $TagContent
    } else {
        # 检查是否存在传统的文件引用格式
        $FileRefPattern = "(?m)^$TagName\s+.*$"
        if ($ConfigContent -match $FileRefPattern) {
            # 如果存在文件引用格式，替换为XML标签格式
            Write-Host "将文件引用格式 '$TagName' 替换为XML标签格式"
            $ConfigContent = $ConfigContent -replace $FileRefPattern, $TagContent
        } else {
            # 如果都不存在，添加到文件末尾
            Write-Host "添加新的 <$TagName> 标签到配置文件末尾"
            $ConfigContent = $ConfigContent.TrimEnd() + "`n`n$TagContent"
        }
    }
    
    return $ConfigContent
}

# 主程序开始
Write-Host "开始合并OpenVPN配置文件..." -ForegroundColor Green
Write-Host "配置文件: $ConfigFile" -ForegroundColor Yellow
Write-Host "Key文件: $KeyFile" -ForegroundColor Yellow
Write-Host "证书文件: $CertFile" -ForegroundColor Yellow
Write-Host "CA文件: $CaFile" -ForegroundColor Yellow
Write-Host ""

# 检查所有必需的文件是否存在
$FilesToCheck = @(
    @{Path = $ConfigFile; Type = "配置文件"},
    @{Path = $KeyFile; Type = "Key文件"},
    @{Path = $CertFile; Type = "证书文件"},
    @{Path = $CaFile; Type = "CA文件"}
)

foreach ($File in $FilesToCheck) {
    if (-not (Test-FileExists -FilePath $File.Path -FileType $File.Type)) {
        exit 1
    }
}

# 读取配置文件内容
$ConfigContent = Get-FileContent -FilePath $ConfigFile
if ($null -eq $ConfigContent) {
    Write-Error "无法读取配置文件: $ConfigFile"
    exit 1
}

# 读取并合并key文件
Write-Host "处理key文件..." -ForegroundColor Cyan
$KeyContent = Get-FileContent -FilePath $KeyFile
if ($null -ne $KeyContent) {
    $ConfigContent = Merge-FileToConfig -ConfigContent $ConfigContent -FileContent $KeyContent -TagName "key" -FileName $KeyFile
}

# 读取并合并证书文件
Write-Host "处理证书文件..." -ForegroundColor Cyan
$CertContent = Get-FileContent -FilePath $CertFile
if ($null -ne $CertContent) {
    $ConfigContent = Merge-FileToConfig -ConfigContent $ConfigContent -FileContent $CertContent -TagName "cert" -FileName $CertFile
}

# 读取并合并CA文件
Write-Host "处理CA文件..." -ForegroundColor Cyan
$CaContent = Get-FileContent -FilePath $CaFile
if ($null -ne $CaContent) {
    $ConfigContent = Merge-FileToConfig -ConfigContent $ConfigContent -FileContent $CaContent -TagName "ca" -FileName $CaFile
}

# 保存合并后的配置文件
try {
    # 创建备份文件
    $BackupFile = "$ConfigFile.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    Copy-Item $ConfigFile $BackupFile
    Write-Host "已创建备份文件: $BackupFile" -ForegroundColor Green
    
    # 在保存前追加所需的TLS相关指令（若不存在同类指令则不追加）
    $ConfigContent = Add-DirectiveIfMissing -ConfigContent $ConfigContent -DirectiveKey "tls-cipher" -DirectiveLine "tls-cipher \"DEFAULT:@SECLEVEL=0\""
    $ConfigContent = Add-DirectiveIfMissing -ConfigContent $ConfigContent -DirectiveKey "tls-version-min" -DirectiveLine "tls-version-min 1.0"

    # 保存合并后的内容
    Set-Content -Path $ConfigFile -Value $ConfigContent -Encoding UTF8
    Write-Host "配置文件已成功更新: $ConfigFile" -ForegroundColor Green
}
catch {
    Write-Error "保存配置文件失败: $($_.Exception.Message)"
    exit 1
}

Write-Host ""
Write-Host "OpenVPN配置文件合并完成！" -ForegroundColor Green
Write-Host "原始文件已备份为: $BackupFile" -ForegroundColor Yellow
