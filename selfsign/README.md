# 证书生成脚本

本目录提供一套基于 `sign.sh` 的证书签发流程：

- `request.txt`：OpenSSL request 配置模板（使用占位符）
- `gen-cert.sh`：根据模板生成实际 request 文件，并调用 `sign.sh` 生成证书
- `sign.sh`：在指定域名目录内生成私钥、CSR、证书与证书链

## 模板占位符

`request.txt` 中使用 `{{DOMAIN}}` 作为主域名占位符（用于 `CN` 和 `DNS.1`）。

`gen-cert.sh` 会把 `{{DOMAIN}}` 替换为你传入的主域名参数。

## 前置条件

- 你需要在本目录下准备 CA 文件：
  - `ca/ca.key`
  - `ca/ca.pem`
- 运行环境需要有 `bash` 和 `openssl`
  - Windows 下建议使用 Git Bash 或 WSL 来执行这些 `.sh` 脚本

## 用法

```bash
chmod +x gen-cert.sh sign.sh
./gen-cert.sh <主域名> [DNS.2] [DNS.3] ...
```

### 示例

仅生成 `harbor.my`：

```bash
./gen-cert.sh harbor.my
```

生成 `harbor.my`，并追加 SAN：

```bash
./gen-cert.sh harbor.my registry.harbor.my notary.harbor.my
```

## 输出

脚本会在当前目录下创建一个以主域名命名的目录（例如 `harbor.my/`），并生成：

- `request`：由 `request.txt` 生成的 OpenSSL 配置（供 `sign.sh` 使用）
- `domain.key`：私钥
- `domain.csr`：CSR
- `domain.pem`：签发后的证书
- `chain`：证书链（`domain.pem` + `ca/ca.pem`）

