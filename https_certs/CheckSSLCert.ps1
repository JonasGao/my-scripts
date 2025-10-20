param(
    [Parameter(Mandatory=$true, HelpMessage="需要检查的域名列表（多个域名用空格分隔）")]
    [string[]]$Domains
)

# 存储所有结果的数组
$results = @()

foreach ($domain in $Domains) {
    $errorMsg = $null
    $cert = $null
    $tcpClient = $null
    $sslStream = $null
    $ipAddress = "N/A"

    try {
        # 解析域名获取IP地址
        try {
            $ipAddress = [System.Net.Dns]::GetHostEntry($domain).AddressList[0].IPAddressToString
        } catch {
            $ipAddress = "解析失败"
        }

        # 创建TCP连接
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        # 使用异步连接方法实现超时
        $connectionTask = $tcpClient.ConnectAsync($domain, 443)
        # 等待连接完成，最多等待5秒
        if (-not $connectionTask.Wait(5000)) {
            throw New-Object System.TimeoutException("连接超时，超过5秒")
        }

        # 建立SSL连接
        $sslStream = New-Object System.Net.Security.SslStream(
            $tcpClient.GetStream(), 
            $false, 
            { param($sender, $cert, $chain, $errors) return $true }  # 忽略证书验证错误
        )
        $sslStream.AuthenticateAsClient($domain)

        # 获取证书
        $remoteCert = $sslStream.RemoteCertificate
        if ($remoteCert) {
            $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($remoteCert)
        } else {
            $errorMsg = "未获取到证书"
        }
    }
    catch {
        $errorMsg = "连接错误: " + $_.Exception.Message
    }
    finally {
        # 清理资源
        if ($sslStream) { $sslStream.Dispose() }
        if ($tcpClient) { $tcpClient.Close() }
    }

    # 处理错误情况
    if ($errorMsg -or -not $cert) {
        $results += [PSCustomObject]@{
            域名       = $domain
            IP地址     = $ipAddress
            开始时间   = "N/A"
            开始年份   = "N/A"
            结束时间   = "N/A"
            结束年份   = "N/A"
            剩余天数   = "N/A"
            状态       = $errorMsg
            表情       = "❌"
        }
        continue
    }

    # 计算证书有效期信息
    $now = Get-Date
    $notBefore = $cert.NotBefore
    $notAfter = $cert.NotAfter
    $expiresIn = $notAfter - $now
    $daysLeft = [math]::Round($expiresIn.TotalDays, 1)
    
    # 提取年份信息
    $startYear = $notBefore.Year
    $endYear = $notAfter.Year

    # 确定过期状态和表情
    if ($daysLeft -le 0) {
        $emoji = "🔴"
        $status = "已过期"
    }
    elseif ($daysLeft -le 30) {
        $emoji = "🔴"
        $status = "1个月内过期"
    }
    elseif ($daysLeft -le 60) {
        $emoji = "🟡"
        $status = "2个月内过期"
    }
    elseif ($daysLeft -le 90) {
        $emoji = "🔵"
        $status = "3个月内过期"
    }
    else {
        $emoji = "✅"
        $status = "有效期充足"
    }

    # 添加到结果集
    $results += [PSCustomObject]@{
        域名       = $domain
        IP地址     = $ipAddress
        开始时间   = $notBefore.ToString("yyyy-MM-dd HH:mm:ss")
        开始年份   = $startYear
        结束时间   = $notAfter.ToString("yyyy-MM-dd HH:mm:ss")
        结束年份   = $endYear
        剩余天数   = $daysLeft
        状态       = "$emoji $status"
        表情       = $emoji
    }
}

# 使用Format-Table输出结果
# 创建一个新的对象数组，用于格式化输出
$formattedResults = $results | ForEach-Object {
    # 创建一个新对象，保留原始对象的属性
    $obj = [PSCustomObject]@{
        域名 = $_.域名
        IP地址 = $_.IP地址
        开始时间 = $_.开始时间
        开始年份 = $_.开始年份
        结束时间 = $_.结束时间
        结束年份 = $_.结束年份
        剩余天数 = $_.剩余天数
        状态 = $_.状态
        表情 = $_.表情  # 保留表情信息
    }
    # 返回新对象
    $obj
}

# 定义表格格式
$formatParams = @{
    AutoSize = $true
    Property = '域名', 'IP地址', '开始年份', '结束年份', '开始时间', '结束时间', '剩余天数', '状态'
}

# 输出表格
$formattedResults | Format-Table @formatParams

# 输出表情状态说明
Write-Host "`n证书状态表情说明："
Write-Host "✅ 有效期充足 (超过90天)"
Write-Host "🔵 3个月内过期 (61-90天)"
Write-Host "🟡 2个月内过期 (31-60天)"
Write-Host "🔴 1个月内过期或已过期 (0-30天)"
Write-Host "❌ 无法获取证书或连接错误"