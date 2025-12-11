# Git Commit Message 规范

本文档定义了本仓库的 Git Commit Message 规范，旨在保持提交历史的清晰、一致和可追溯。

## 规范格式

每个 Commit Message 应遵循以下格式：

```
<type>(<scope>): <subject>

<body>

<footer>
```

### 格式说明

- **Header（必需）**：包含类型、作用域和主题，单行，不超过 72 个字符
- **Body（可选）**：详细描述，说明修改的原因和方式，每行不超过 72 个字符
- **Footer（可选）**：用于关闭 Issue 或引用相关资源

## Type（类型）

类型必须是以下之一：

- **feat**: 新功能（新增脚本或功能）
- **fix**: 修复 bug（修复脚本中的错误）
- **docs**: 文档更新（README、注释等）
- **style**: 代码格式调整（不影响代码运行的格式修改）
- **refactor**: 代码重构（既不是新功能也不是 bug 修复）
- **perf**: 性能优化（提升脚本执行效率）
- **test**: 测试相关（添加或修改测试）
- **chore**: 构建/工具/依赖相关（配置文件、构建脚本等）
- **ci**: CI/CD 相关（持续集成配置）
- **build**: 构建系统相关
- **revert**: 回滚之前的提交

## Scope（作用域）

作用域用于标识修改所属的模块或目录，建议使用以下作用域：

- **docker**: Docker 相关脚本
- **github**: GitHub 相关脚本
- **https_certs**: HTTPS 证书相关脚本
- **openvpn**: OpenVPN 相关脚本
- **powershell**: PowerShell 脚本
- **spring-boot**: Spring Boot 相关脚本
- **selfsign**: 自签名证书相关脚本
- **helper**: 辅助工具脚本
- **old_deploy_scripts**: 旧部署脚本
- **config**: 配置文件
- **docs**: 文档文件

如果修改涉及多个模块，可以使用 `*` 或省略作用域。

## Subject（主题）

主题应该：

- 使用祈使句，现在时态（如 "add" 而不是 "added" 或 "adds"）
- 首字母小写（除非是专有名词）
- 不以句号结尾
- 简洁明了，描述本次提交的核心内容

## Body（正文）

正文应该：

- 说明**为什么**进行这次修改，而不是**做了什么**（做了什么在 subject 中已经说明）
- 可以包含修改前后的对比
- 可以说明可能的影响或注意事项
- 每行不超过 72 个字符
- 使用空行与 Header 和 Footer 分隔

## Footer（脚注）

Footer 用于：

- 关闭 Issue：`Closes #123`、`Fixes #456`
- 引用相关资源：`Refs #789`
- 说明破坏性变更：`BREAKING CHANGE: <description>`

## 示例

### 示例 1：新功能

```
feat(docker): add docker-ip plugin script

Add a Docker CLI plugin script to query container IP addresses.
Supports querying multiple containers at once.

Closes #10
```

### 示例 2：修复 Bug

```
fix(github): handle empty gist content correctly

When gist file content is empty, the script now attempts to
download from raw_url instead of failing silently.

Fixes #15
```

### 示例 3：文档更新

```
docs(openvpn): update merge-ovpn-config usage guide

Add examples for different parameter combinations and clarify
the backup behavior.
```

### 示例 4：代码重构

```
refactor(spring-boot): simplify service control logic

Extract common service operations into reusable functions
to reduce code duplication across v2 and v3 scripts.
```

### 示例 5：性能优化

```
perf(powershell): optimize gist download pagination

Reduce API calls by increasing per_page limit from 30 to 100,
significantly improving download speed for large gist collections.
```

### 示例 6：样式调整

```
style(https_certs): format script with consistent indentation

Apply 2-space indentation consistently across all bash scripts
in the https_certs directory.
```

### 示例 7：多模块修改

```
feat(*): add error handling to all download scripts

Add comprehensive error handling and retry logic to all scripts
that perform network operations, including:
- github/Download-Gists.ps1
- docker/xpull
- docker/xppull
```

### 示例 8：破坏性变更

```
feat(spring-boot): restructure deployment scripts

BREAKING CHANGE: Move all Spring Boot deployment scripts to
a new unified structure. Old scripts in root directory are
deprecated and will be removed in next version.

Migration guide:
- Use spring-boot/v3/deploy-app.sh instead of deploy.sh
- Update CI/CD pipelines to use new script paths
```

## 提交检查清单

提交前请确认：

- [ ] Commit message 遵循规范格式
- [ ] Type 和 Scope 使用正确
- [ ] Subject 简洁明了，使用祈使句
- [ ] 代码已通过测试（如有）
- [ ] 相关文档已更新（如需要）
- [ ] 没有提交临时文件或敏感信息

## 工具支持

### Commitizen

可以使用 [Commitizen](https://github.com/commitizen/cz-cli) 来帮助生成符合规范的 commit message：

```bash
npm install -g commitizen
npm install -g cz-conventional-changelog
echo '{ "path": "cz-conventional-changelog" }' > ~/.czrc
```

然后使用 `git cz` 代替 `git commit`。

### Git Hooks

可以配置 pre-commit hook 来检查 commit message 格式，推荐使用 [commitlint](https://github.com/conventional-changelog/commitlint)。

## 参考资源

- [Conventional Commits](https://www.conventionalcommits.org/)
- [Angular Commit Message Guidelines](https://github.com/angular/angular/blob/main/CONTRIBUTING.md#commit)
- [Git Commit Best Practices](https://chris.beams.io/posts/git-commit/)

## 更新日志

本规范会根据项目需要持续更新和完善。
