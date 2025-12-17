param(
    [Parameter(Mandatory=$true)][string]$Namespace,
    [Parameter(Mandatory=$true)][string]$ServiceAccount,
    [string]$SecretName,
    [string]$Context,
    [string]$OutputFile = "kubeconfig-$ServiceAccount-$Namespace.yaml",
    [string]$ClusterName = "kubernetes",
    [string]$ContextName = "$ServiceAccount-$Namespace",
    [string]$User = "$ServiceAccount-$Namespace",
    [switch]$WhatIf
)

# 构建 kubectl 命令的 context 参数
$kubectlContextArg = if ($Context) { "--context $Context" } else { "" }

# 获取当前集群的 API Server 地址
$apiServer = Invoke-Expression "kubectl config view $kubectlContextArg --minify -o jsonpath='{.clusters[0].cluster.server}'"

# 获取集群的 CA 证书数据
$caCertData = Invoke-Expression "kubectl config view $kubectlContextArg --minify --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}'"

# 获取 service account 对应的 secret 名称
if (-not $SecretName) {
    # 尝试从 service account 中获取 secret 名称
    $secretName = Invoke-Expression "kubectl get serviceaccount $ServiceAccount -n $Namespace $kubectlContextArg -o jsonpath='{.secrets[0].name}'"
    
    # 如果没有获取到，尝试通过 annotations 查找关联的 secret
    if (-not $secretName) {
        $jsonpath = '{range .items[?(@.metadata.annotations.kubernetes\.io/service-account\.name=="'+$ServiceAccount+'")]}{.metadata.name}{end}'
        $secretName = Invoke-Expression "kubectl get secret -n $Namespace $kubectlContextArg -o jsonpath='$jsonpath'"
    }
    
    if (-not $secretName) {
        Write-Host "Error: No secret found for service account $ServiceAccount in namespace $Namespace"
        exit 1
    }
} else {
    $secretName = $SecretName
}

# 获取 secret 中的 token
$encodedToken = Invoke-Expression "kubectl get secret $secretName -n $Namespace $kubectlContextArg -o jsonpath='{.data.token}'"
if (-not $encodedToken) {
    Write-Host "Error: Failed to get token from secret $secretName"
    exit 1
}

# 使用 PowerShell 内置的 base64 解码
$tokenBytes = [System.Convert]::FromBase64String($encodedToken)
$token = [System.Text.Encoding]::UTF8.GetString($tokenBytes)

# 生成 kubeconfig 内容
$kubeconfig = @"
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: $caCertData
    server: $apiServer
  name: $ClusterName
contexts:
- context:
    cluster: $ClusterName
    user: $User
    namespace: $Namespace
  name: $ContextName
current-context: $ContextName
kind: Config
preferences: {}
users:
- name: $User
  user:
    token: $token
"@

# 输出到文件
if ($WhatIf) {
    Write-Host "What if: Would generate kubeconfig file: $OutputFile"
    Write-Host "What if: File content would include cluster: $ClusterName, user: $User, namespace: $Namespace"
    Write-Host "What if: Use with: kubectl --kubeconfig=$OutputFile <command>"
} else {
    $kubeconfig | Out-File -FilePath $OutputFile -Encoding UTF8
    Write-Host "Kubeconfig file generated successfully: $OutputFile"
    Write-Host "Use with: kubectl --kubeconfig=$OutputFile <command>"
}
