#!/usr/bin/env pwsh
<#
.SYNOPSIS
读取PEM证书和KEY文件并显示证书的详细信息

.DESCRIPTION
此脚本可以读取PEM格式的证书文件（支持证书链）和对应的私钥文件，并显示证书的完整信息，包括主题、颁发者、有效期、序列号、公钥信息等。

.PARAMETER CertFile
PEM格式证书文件的路径

.PARAMETER KeyFile
私钥文件的路径（可选）

.PARAMETER Password
私钥文件的密码（如果有）

.EXAMPLE
Get-CertificateFromPemAndKey.ps1 -CertFile .\server.crt -KeyFile .\server.key

.EXAMPLE
Get-CertificateFromPemAndKey.ps1 -CertFile .\server.crt -KeyFile .\server.key -Password "MySecurePassword"
#>

param (
    [Parameter(Mandatory=$true, HelpMessage="PEM格式证书文件路径")]
    [ValidateScript({Test-Path $_ -PathType Leaf})]
    [string]$CertFile,
    
    [Parameter(HelpMessage="私钥文件路径")]
    [ValidateScript({if ([string]::IsNullOrEmpty($_)) {return $true} else {Test-Path $_ -PathType Leaf}})]
    [string]$KeyFile = "",
    
    [Parameter(HelpMessage="私钥密码")]
    [string]$Password = ""
)

function Convert-PemToCertificate {
    <#
    .SYNOPSIS
    将PEM格式的证书转换为X509Certificate2对象数组
    #>
    param (
        [string]$PemContent
    )
    
    # 提取所有证书内容
    $certPattern = '-----BEGIN CERTIFICATE-----([\s\S]+?)-----END CERTIFICATE-----'
    $certMatches = [regex]::Matches($PemContent, $certPattern)
    
    if (-not $certMatches.Success -or $certMatches.Count -eq 0) {
        throw "未找到有效的PEM格式证书内容"
    }
    
    $certificates = @()
    
    foreach ($match in $certMatches) {
        $certBase64 = $match.Groups[1].Value -replace '\s', ''
        
        try {
            # 转换为字节数组
            $certBytes = [Convert]::FromBase64String($certBase64)
            
            # 使用正确的构造函数参数传递方式
            $certificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($certBytes)
            $certificates += $certificate
        }
        catch {
            Write-Warning "处理证书时出错: $_"
        }
    }
    
    if ($certificates.Count -eq 0) {
        throw "无法成功转换任何证书"
    }
    
    return $certificates
}

function Get-CertificateType {
    <#
    .SYNOPSIS
    确定证书类型（终端实体证书、中间CA或根CA）
    #>
    param (
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate
    )
    
    # 检查是否是CA证书
    $basicConstraintsExt = $Certificate.Extensions | Where-Object { $_.Oid.Value -eq "2.5.29.19" }
    if ($basicConstraintsExt) {
        $basicConstraints = [System.Security.Cryptography.X509Certificates.X509BasicConstraintsExtension]$basicConstraintsExt
        if ($basicConstraints.CertificateAuthority) {
            # 检查主题和颁发者是否相同（根CA的特征）
            if ($Certificate.Subject -eq $Certificate.Issuer) {
                return "根CA证书"
            } else {
                return "中间CA证书"
            }
        }
    }
    
    # 默认是终端实体证书
    return "终端实体证书"
}

function Display-CertificateInfo {
    <#
    .SYNOPSIS
    显示X509证书的详细信息
    #>
    param (
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate,
        [int]$CertificateIndex = 1,
        [int]$TotalCertificates = 1,
        [string]$CertificateType = "证书"
    )
    
    Write-Host "==========================================" -ForegroundColor Green
    if ($TotalCertificates -gt 1) {
        Write-Host "$CertificateType (证书 $CertificateIndex/$TotalCertificates)" -ForegroundColor Green
    } else {
        Write-Host "证书详细信息" -ForegroundColor Green
    }
    Write-Host "==========================================" -ForegroundColor Green
    
    # 基本信息
    Write-Host "证书主题: $($Certificate.Subject)" -ForegroundColor Cyan
    Write-Host "颁发者: $($Certificate.Issuer)" -ForegroundColor Cyan
    Write-Host "序列号: $($Certificate.SerialNumber)" -ForegroundColor Cyan
    Write-Host "指纹: $($Certificate.Thumbprint)" -ForegroundColor Cyan
    Write-Host "版本: $($Certificate.Version)" -ForegroundColor Cyan
    
    # 有效期信息
    Write-Host "开始日期: $($Certificate.NotBefore)" -ForegroundColor Cyan
    Write-Host "结束日期: $($Certificate.NotAfter)" -ForegroundColor Cyan
    
    # 检查证书是否已过期或即将过期
    $now = Get-Date
    if ($Certificate.NotAfter -lt $now) {
        Write-Host "证书状态: 已过期" -ForegroundColor Red
    } 
    elseif (($Certificate.NotAfter - $now).Days -lt 30) {
        Write-Host "证书状态: 即将过期 ($(($Certificate.NotAfter - $now).Days) 天后)" -ForegroundColor Yellow
    } 
    else {
        Write-Host "证书状态: 有效" -ForegroundColor Green
    }
    
    # 扩展信息
    Write-Host "`n扩展信息:" -ForegroundColor Yellow
    foreach ($extension in $Certificate.Extensions) {
        Write-Host "- $($extension.Oid.FriendlyName) ($($extension.Oid.Value))" -ForegroundColor White
        
        # 显示某些特定扩展的详细信息
        switch ($extension.Oid.Value) {
            "2.5.29.17" { # 主题备用名称
                $san = [System.Security.Cryptography.X509Certificates.X509SubjectAlternativeNameExtension]$extension
                Write-Host "  备用名称: $($san.DnsNames -join ', ')" -ForegroundColor Gray
                break
            }
            "2.5.29.37" { # 增强型密钥用法
                $eku = [System.Security.Cryptography.X509Certificates.X509EnhancedKeyUsageExtension]$extension
                # 正确处理增强型密钥用法
                $ekuOids = @()
                foreach ($oid in $eku.EnhancedKeyUsages) {
                    $friendlyName = $oid.FriendlyName
                    if ([string]::IsNullOrEmpty($friendlyName)) {
                        $friendlyName = $oid.Value
                    }
                    $ekuOids += $friendlyName
                }
                Write-Host "  增强型密钥用法: $($ekuOids -join ', ')" -ForegroundColor Gray
                break
            }
            default {
                # 尝试以可读形式显示其他扩展
                try {
                    Write-Host "  内容: $($extension.Format($true))" -ForegroundColor Gray
                } catch {
                    Write-Host "  内容: (无法格式化为可读文本)" -ForegroundColor Gray
                }
            }
        }
    }
    
    # 公钥信息
    Write-Host "`n公钥信息:" -ForegroundColor Yellow
    Write-Host "算法: $($Certificate.PublicKey.Oid.FriendlyName) ($($Certificate.PublicKey.Oid.Value))" -ForegroundColor White
    
    # 尝试获取更多公钥细节
    try {
        # 安全地获取密钥大小
        $keySize = $Certificate.PublicKey.Key.KeySize
        Write-Host "密钥大小: $keySize 位" -ForegroundColor White
        
        # 显示密钥算法
        Write-Host "密钥算法: $($Certificate.PublicKey.Oid.FriendlyName)" -ForegroundColor White
    } catch {
        Write-Host "无法获取公钥详细信息: $_" -ForegroundColor Red
    }
    
    Write-Host "==========================================" -ForegroundColor Green
}

function Test-PrivateKeyMatch {
    <#
    .SYNOPSIS
    测试私钥是否与证书匹配
    #>
    param (
        [string]$CertFile,
        [string]$KeyFile,
        [string]$Password = ""
    )
    
    try {
        # 检查OpenSSL是否可用
        $openssl = Get-Command openssl -ErrorAction SilentlyContinue
        if (-not $openssl) {
            Write-Warning "未找到OpenSSL，无法验证私钥与证书是否匹配。请安装OpenSSL后重试。"
            return $false
        }
        
        # 创建临时文件
        $tempDir = [System.IO.Path]::GetTempPath()
        $certFingerprintFile = [System.IO.Path]::Combine($tempDir, "cert_fingerprint.txt")
        $keyFingerprintFile = [System.IO.Path]::Combine($tempDir, "key_fingerprint.txt")
        
        # 获取证书的公钥指纹
        if ($Password) {
            $opensslCertCmd = "openssl x509 -in '$CertFile' -noout -modulus | openssl md5 > '$certFingerprintFile'"
            $opensslKeyCmd = "openssl rsa -in '$KeyFile' -passin pass:$Password -noout -modulus | openssl md5 > '$keyFingerprintFile'"
        } else {
            $opensslCertCmd = "openssl x509 -in '$CertFile' -noout -modulus | openssl md5 > '$certFingerprintFile'"
            $opensslKeyCmd = "openssl rsa -in '$KeyFile' -noout -modulus | openssl md5 > '$keyFingerprintFile'"
        }
        
        # 执行命令
        Invoke-Expression -Command $opensslCertCmd -ErrorAction Stop
        Invoke-Expression -Command $opensslKeyCmd -ErrorAction Stop
        
        # 比较指纹
        $certFingerprint = Get-Content -Path $certFingerprintFile -Raw
        $keyFingerprint = Get-Content -Path $keyFingerprintFile -Raw
        
        # 清理临时文件
        Remove-Item -Path $certFingerprintFile, $keyFingerprintFile -Force -ErrorAction SilentlyContinue
        
        # 返回比较结果
        return ($certFingerprint -eq $keyFingerprint)
    }
    catch {
        Write-Error "私钥匹配测试失败: $_"
        return $false
    }
}

# 主脚本开始
try {
    # 读取证书文件内容
    Write-Host "正在读取证书文件: $CertFile" -ForegroundColor Yellow
    $certContent = Get-Content -Path $CertFile -Raw -ErrorAction Stop
    
    # 转换为X509Certificate2对象数组
    $certificates = Convert-PemToCertificate -PemContent $certContent
    
    Write-Host "找到 $($certificates.Count) 个证书" -ForegroundColor Yellow
    
    # 显示每个证书的信息
    for ($i = 0; $i -lt $certificates.Count; $i++) {
        $certIndex = $i + 1
        $certType = Get-CertificateType -Certificate $certificates[$i]
        Display-CertificateInfo -Certificate $certificates[$i] -CertificateIndex $certIndex -TotalCertificates $certificates.Count -CertificateType $certType
        
        # 不是最后一个证书时，添加空行分隔
        if ($i -lt ($certificates.Count - 1)) {
            Write-Host ""
        }
    }
    
    # 如果提供了密钥文件，验证是否存在并尝试匹配测试
    if (-not [string]::IsNullOrEmpty($KeyFile)) {
        Write-Host "`n正在检查私钥文件: $KeyFile" -ForegroundColor Yellow
        if (Test-Path $KeyFile -PathType Leaf) {
            # 尝试使用OpenSSL验证私钥与证书匹配（通常私钥只与第一个证书匹配）
            $keyMatchResult = Test-PrivateKeyMatch -CertFile $CertFile -KeyFile $KeyFile -Password $Password
            if ($keyMatchResult) {
                Write-Host "私钥与第一个证书匹配: 是" -ForegroundColor Green
            } elseif ($keyMatchResult -eq $false) {
                Write-Host "私钥与证书匹配: 否" -ForegroundColor Red
            }
        } else {
            Write-Host "警告: 找不到私钥文件: $KeyFile" -ForegroundColor Yellow
        }
    }
}
catch {
    Write-Host "错误: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`n证书信息读取完成" -ForegroundColor Green
exit 0