# PowerShell 脚本：从 GitHub 下载所有 Gist
# 支持命令行参数和交互输入

param(
    [Parameter(Mandatory=$false)]
    [string]$GitHubToken,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputDirectory
)

# GitHub API 基础 URL
$GitHubApiBaseUrl = "https://api.github.com"

function Get-AllGists {
    param(
        [string]$Token
    )
    
    $allGists = @()
    $page = 1
    $perPage = 100
    
    Write-Host "正在获取 Gist 列表..." -ForegroundColor Yellow
    
    while ($true) {
        try {
            $headers = @{
                "Authorization" = "token $Token"
                "Accept" = "application/vnd.github.v3+json"
                "User-Agent" = "PowerShell-Gist-Downloader"
            }
            
            $url = "$GitHubApiBaseUrl/gists?page=$page&per_page=$perPage"
            Write-Host "正在获取第 $page 页..." -ForegroundColor Gray
            
            $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
            
            if ($response.Count -eq 0) {
                break
            }
            
            $allGists += $response
            Write-Host "已获取 $($response.Count) 个 Gist（总计: $($allGists.Count)）" -ForegroundColor Green
            
            # 如果返回的 Gist 数量少于每页数量，说明已经是最后一页
            if ($response.Count -lt $perPage) {
                break
            }
            
            $page++
        }
        catch {
            Write-Host "获取 Gist 时出错: $_" -ForegroundColor Red
            if ($_.Exception.Response.StatusCode -eq 401) {
                Write-Host "认证失败，请检查 GitHub Token 是否正确" -ForegroundColor Red
            }
            break
        }
    }
    
    return $allGists
}

function Save-Gist {
    param(
        [object]$Gist,
        [string]$OutputDir
    )
    
    $gistId = $Gist.id
    $gistDescription = $Gist.description
    if ([string]::IsNullOrWhiteSpace($gistDescription)) {
        $gistDescription = "无描述"
    }
    
    # 创建 Gist 目录（使用 ID 和描述作为目录名）
    $safeDescription = $gistDescription -replace '[<>:"/\\|?*]', '_'
    $gistDirName = "$gistId`_$safeDescription"
    $gistDir = Join-Path $OutputDir $gistDirName
    
    if (-not (Test-Path $gistDir)) {
        New-Item -ItemType Directory -Path $gistDir -Force | Out-Null
    }
    
    Write-Host "正在下载 Gist: $gistDescription ($gistId)" -ForegroundColor Cyan
    
    # 下载所有文件
    $files = $Gist.files.PSObject.Properties
    foreach ($file in $files) {
        $fileName = $file.Name
        $fileContent = $file.Value.content
        $filePath = Join-Path $gistDir $fileName
        
        try {
            # 如果文件内容为空，尝试从 raw_url 下载
            if ([string]::IsNullOrWhiteSpace($fileContent)) {
                $rawUrl = $file.Value.raw_url
                if ($rawUrl) {
                    Write-Host "  从 URL 下载文件: $fileName" -ForegroundColor Gray
                    $headers = @{
                        "Authorization" = "token $script:GitHubToken"
                        "User-Agent" = "PowerShell-Gist-Downloader"
                    }
                    $fileContent = Invoke-RestMethod -Uri $rawUrl -Headers $headers -Method Get
                }
            }
            
            # 保存文件
            [System.IO.File]::WriteAllText($filePath, $fileContent, [System.Text.Encoding]::UTF8)
            Write-Host "  ✓ $fileName" -ForegroundColor Green
        }
        catch {
            Write-Host "  ✗ 下载文件 $fileName 失败: $_" -ForegroundColor Red
        }
    }
    
    # 保存 Gist 元数据
    $metadataPath = Join-Path $gistDir "_metadata.json"
    $metadata = @{
        id = $Gist.id
        description = $Gist.description
        public = $Gist.public
        created_at = $Gist.created_at
        updated_at = $Gist.updated_at
        html_url = $Gist.html_url
        git_pull_url = $Gist.git_pull_url
        git_push_url = $Gist.git_push_url
        owner = $Gist.owner
    } | ConvertTo-Json -Depth 10
    
    [System.IO.File]::WriteAllText($metadataPath, $metadata, [System.Text.Encoding]::UTF8)
}

function Main {
    # 获取 GitHub Token
    if ([string]::IsNullOrWhiteSpace($GitHubToken)) {
        Write-Host "请输入 GitHub Personal Access Token:" -ForegroundColor Yellow
        Write-Host "(如果没有 Token，请访问 https://github.com/settings/tokens 创建)" -ForegroundColor Gray
        $secureToken = Read-Host -AsSecureString
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
        $GitHubToken = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    }
    
    if ([string]::IsNullOrWhiteSpace($GitHubToken)) {
        Write-Host "错误: GitHub Token 不能为空" -ForegroundColor Red
        exit 1
    }
    
    # 保存 Token 到脚本作用域，供其他函数使用
    $script:GitHubToken = $GitHubToken
    
    # 获取输出目录
    if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
        Write-Host "请输入输出目录路径（留空使用当前目录下的 'gists' 文件夹）:" -ForegroundColor Yellow
        $userInput = Read-Host
        if ([string]::IsNullOrWhiteSpace($userInput)) {
            $OutputDirectory = Join-Path (Get-Location) "gists"
        } else {
            $OutputDirectory = $userInput
        }
    }
    
    # 确保输出目录存在
    if (-not (Test-Path $OutputDirectory)) {
        Write-Host "创建输出目录: $OutputDirectory" -ForegroundColor Yellow
        New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    }
    
    Write-Host "输出目录: $OutputDirectory" -ForegroundColor Green
    Write-Host ""
    
    # 获取所有 Gist
    $gists = Get-AllGists -Token $GitHubToken
    
    if ($gists.Count -eq 0) {
        Write-Host "未找到任何 Gist" -ForegroundColor Yellow
        exit 0
    }
    
    Write-Host ""
    Write-Host "找到 $($gists.Count) 个 Gist，开始下载..." -ForegroundColor Green
    Write-Host ""
    
    # 下载每个 Gist
    $successCount = 0
    $failCount = 0
    
    foreach ($gist in $gists) {
        try {
            Save-Gist -Gist $gist -OutputDir $OutputDirectory
            $successCount++
        }
        catch {
            Write-Host "下载 Gist $($gist.id) 失败: $_" -ForegroundColor Red
            $failCount++
        }
    }
    
    Write-Host ""
    Write-Host "=" * 50 -ForegroundColor Cyan
    Write-Host "下载完成！" -ForegroundColor Green
    Write-Host "成功: $successCount" -ForegroundColor Green
    Write-Host "失败: $failCount" -ForegroundColor $(if ($failCount -gt 0) { "Red" } else { "Green" })
    Write-Host "输出目录: $OutputDirectory" -ForegroundColor Cyan
    Write-Host "=" * 50 -ForegroundColor Cyan
}

# 运行主函数
Main
