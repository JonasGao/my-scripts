# OpenVPN配置文件合并脚本使用说明

## 脚本功能
`merge-ovpn-config.ps1` 脚本用于将OpenVPN的key、证书和CA证书文件内容合并到配置文件中。

## 使用方法

### 基本用法（使用默认文件名）
```powershell
.\merge-ovpn-config.ps1
```

### 指定文件名
```powershell
.\merge-ovpn-config.ps1 -ConfigFile "my-config.ovpn" -KeyFile "my-key.key" -CertFile "my-cert.crt" -CaFile "my-ca.crt"
```

## 参数说明
- `ConfigFile`: OpenVPN配置文件路径（默认：client.ovpn）
- `KeyFile`: 客户端key文件路径（默认：client.key）
- `CertFile`: 客户端证书文件路径（默认：client.crt）
- `CaFile`: CA证书文件路径（默认：ca.crt）

## 功能特点
1. 自动检查所有必需文件是否存在
2. 使用XML标签格式包装内容：`<key>`、`<cert>`、`<ca>`
3. 支持两种配置格式的转换：
   - 传统文件引用格式：`key client.key`、`cert client.crt`、`ca ca.crt`
   - XML标签格式：`<key>`、`<cert>`、`<ca>`
4. 如果XML标签已存在，会替换现有内容
5. 如果存在传统文件引用格式，会转换为XML标签格式
6. 如果都不存在，会添加到文件末尾
7. 自动创建备份文件
8. 支持UTF-8编码

## 注意事项
- 脚本会在执行前创建原文件的备份
- 所有文件必须存在于当前目录或指定路径
- 合并后的文件会覆盖原配置文件
