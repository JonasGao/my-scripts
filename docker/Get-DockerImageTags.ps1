param(
    [Parameter(Mandatory=$true, HelpMessage="Docker镜像名称，例如：nginx、ubuntu")]
    [string]$ImageName,
    
    [Parameter(Mandatory=$true, HelpMessage="要在版本号中搜索的字符串")]
    [string]$SearchString,
    
    [Parameter(Mandatory=$false, HelpMessage="代理服务器地址，例如：http://proxy.example.com:8080")]
    [string]$Proxy
)

# 配置代理
$proxyConfig = @{}
if ($Proxy) {
    $proxyConfig.Proxy = $Proxy
} elseif ($env:HTTP_PROXY) {
    $proxyConfig.Proxy = $env:HTTP_PROXY
} elseif ($env:HTTPS_PROXY) {
    $proxyConfig.Proxy = $env:HTTPS_PROXY
} elseif ($env:ALL_PROXY) {
    $proxyConfig.Proxy = $env:ALL_PROXY
}

# 初始化变量
$allTags = @()

# 处理官方镜像，添加 library/ 前缀
if ($ImageName -notcontains "/") {
    $ImageName = "library/$ImageName"
}

# 构建API URL，添加按创建时间倒序排序参数
# 注意：Docker Hub API标签端点不直接支持模糊匹配参数，模糊匹配在客户端进行
$nextUrl = "https://registry.hub.docker.com/v2/repositories/$ImageName/tags/?page_size=100&ordering=-last_updated"

# 获取所有标签（处理分页）
do {
    try {
        if ($proxyConfig.Proxy) {
            $response = Invoke-RestMethod -Uri $nextUrl -Method Get -ContentType "application/json" -Proxy $proxyConfig.Proxy
        } else {
            $response = Invoke-RestMethod -Uri $nextUrl -Method Get -ContentType "application/json"
        }
        $allTags += $response.results.name
        $nextUrl = $response.next
    } catch {
        Write-Error "无法获取镜像 $ImageName 的标签：$($_.Exception.Message)"
        exit 1
    }
} while ($nextUrl)

# 筛选包含搜索字符串的标签
$matchingTags = $allTags | Where-Object { $_ -match $SearchString }

# 输出结果
if ($matchingTags.Count -gt 0) {
    Write-Output "镜像 $ImageName 中包含 '$SearchString' 的版本号："
    foreach ($tag in $matchingTags) {
        Write-Output "  - $tag"
    }
    Write-Output ""
    Write-Output "总计：$($matchingTags.Count) 个匹配版本"
} else {
    Write-Output "镜像 $ImageName 中没有找到包含 '$SearchString' 的版本号"
}
