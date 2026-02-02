<#
.SYNOPSIS
    方便地执行 opencode run 命令

.DESCRIPTION
    封装 opencode run 命令，支持传入 prompt 和 model 参数，
    使用子进程方式启动，支持自定义环境变量，与当前进程隔离。

.PARAMETER Prompt
    要发送给 AI 的提示信息（必需）

.PARAMETER Model
    使用的模型，格式为 provider/model
    可用模型列表可通过 opencode models 命令查看

.PARAMETER File
    要附加的文件路径（可选，支持多个）

.PARAMETER Continue
    继续上次的会话

.PARAMETER Session
    指定要继续的会话 ID

.PARAMETER Agent
    使用的 agent

.PARAMETER Title
    会话标题

.PARAMETER Format
    输出格式: default 或 json

.PARAMETER Environment
    自定义环境变量，格式为 hashtable，例如 @{ "KEY" = "VALUE" }
    默认已包含代理设置: HTTP_PROXY 和 HTTPS_PROXY (127.0.0.1:7890)

.PARAMETER WorkingDirectory
    工作目录，默认为当前目录

.EXAMPLE
    Invoke-OpenCode.ps1 -Prompt "解释一下这段代码"

.EXAMPLE
    Invoke-OpenCode.ps1 -Prompt "分析这个文件" -File "./test.ps1"

.EXAMPLE
    Invoke-OpenCode.ps1 -Prompt "帮我写一个脚本" -Model "opencode/kimi-k2.5-free"

.EXAMPLE
    Invoke-OpenCode.ps1 "快速提问内容"

.EXAMPLE
    Invoke-OpenCode.ps1 -Prompt "测试" -Environment @{ "OPENCODE_API_KEY" = "sk-xxx" }

.EXAMPLE
    # 使用不同的代理
    Invoke-OpenCode.ps1 -Prompt "测试" -Environment @{ "HTTP_PROXY" = "http://192.168.1.1:8080"; "HTTPS_PROXY" = "http://192.168.1.1:8080" }

.EXAMPLE
    # 禁用代理
    Invoke-OpenCode.ps1 -Prompt "测试" -Environment @{}
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
    [string]$Prompt,

    [Parameter()]
    [ValidateSet(
        "opencode/big-pickle",
        "opencode/glm-4.7-free",
        "opencode/gpt-5-nano",
        "opencode/kimi-k2.5-free",
        "opencode/minimax-m2.1-free",
        "opencode/trinity-large-preview-free"
    )]
    [string]$Model = "opencode/minimax-m2.1-free",

    [Parameter()]
    [string[]]$File,

    [Parameter()]
    [switch]$Continue,

    [Parameter()]
    [string]$Session,

    [Parameter()]
    [string]$Agent,

    [Parameter()]
    [string]$Title,

    [Parameter()]
    [ValidateSet("default", "json")]
    [string]$Format = "default",

    [Parameter()]
    [hashtable]$Environment = @{
        "HTTP_PROXY"  = "http://xx.my:7890"
        "HTTPS_PROXY" = "http://xx.my:7890"
    },

    [Parameter()]
    [string]$WorkingDirectory = (Get-Location).Path
)

# 构建命令参数
$arguments = @("run")

# 添加模型参数
$arguments += "-m", $Model

# 添加格式参数
$arguments += "--format", $Format

# 添加文件参数
if ($File) {
    foreach ($f in $File) {
        $arguments += "-f", $f
    }
}

# 添加继续会话参数
if ($Continue) {
    $arguments += "-c"
}

# 添加会话 ID 参数
if ($Session) {
    $arguments += "-s", $Session
}

# 添加 agent 参数
if ($Agent) {
    $arguments += "--agent", $Agent
}

# 添加标题参数
if ($Title) {
    $arguments += "--title", $Title
}

# 添加 prompt（放在最后作为位置参数）
$arguments += $Prompt

# 构建参数字符串
$argumentString = $arguments | ForEach-Object {
    if ($_ -match '\s') {
        "`"$_`""
    } else {
        $_
    }
}
$argumentString = $argumentString -join ' '

# 显示将要执行的命令（便于调试）
Write-Verbose "执行命令: opencode $argumentString"
Write-Verbose "工作目录: $WorkingDirectory"
if ($Environment.Count -gt 0) {
    Write-Verbose "自定义环境变量: $($Environment.Keys -join ', ')"
}

# 查找 opencode 可执行文件路径
$opencodeCmd = Get-Command opencode -ErrorAction SilentlyContinue
if (-not $opencodeCmd) {
    throw "找不到 opencode 命令，请确保已安装并在 PATH 中"
}
$opencodePath = $opencodeCmd.Source

# 创建进程启动信息
$processInfo = [System.Diagnostics.ProcessStartInfo]::new()
$processInfo.FileName = $opencodePath
$processInfo.Arguments = $argumentString
$processInfo.WorkingDirectory = $WorkingDirectory
$processInfo.UseShellExecute = $false
$processInfo.RedirectStandardOutput = $true
$processInfo.RedirectStandardError = $true
$processInfo.CreateNoWindow = $false
$processInfo.StandardOutputEncoding = [System.Text.Encoding]::UTF8
$processInfo.StandardErrorEncoding = [System.Text.Encoding]::UTF8

# 设置自定义环境变量（子进程会继承当前进程的环境变量）
foreach ($key in $Environment.Keys) {
    $processInfo.EnvironmentVariables[$key] = $Environment[$key]
    Write-Verbose "设置环境变量: $key"
}

# 创建并启动进程
$process = [System.Diagnostics.Process]::new()
$process.StartInfo = $processInfo

# 使用事件处理来实时输出（避免阻塞）
$outputBuilder = [System.Text.StringBuilder]::new()
$errorBuilder = [System.Text.StringBuilder]::new()

# 注册输出事件
$outputEvent = Register-ObjectEvent -InputObject $process -EventName OutputDataReceived -Action {
    if ($null -ne $EventArgs.Data) {
        Write-Host $EventArgs.Data
    }
}

$errorEvent = Register-ObjectEvent -InputObject $process -EventName ErrorDataReceived -Action {
    if ($null -ne $EventArgs.Data) {
        Write-Host $EventArgs.Data -ForegroundColor Red
    }
}

try {
    # 启动进程
    $null = $process.Start()
    
    # 开始异步读取输出
    $process.BeginOutputReadLine()
    $process.BeginErrorReadLine()
    
    # 等待进程完成
    $process.WaitForExit()
    
    # 返回退出码
    $exitCode = $process.ExitCode
    Write-Verbose "进程退出码: $exitCode"
    
    if ($exitCode -ne 0) {
        Write-Warning "opencode 退出码: $exitCode"
    }
}
finally {
    # 清理事件订阅
    Unregister-Event -SourceIdentifier $outputEvent.Name -ErrorAction SilentlyContinue
    Unregister-Event -SourceIdentifier $errorEvent.Name -ErrorAction SilentlyContinue
    Remove-Job -Name $outputEvent.Name -Force -ErrorAction SilentlyContinue
    Remove-Job -Name $errorEvent.Name -Force -ErrorAction SilentlyContinue
    
    # 释放进程资源
    $process.Dispose()
}
