# 0001 — Web 模式不做认证，也不做 CSRF 防护

## 状态

已接受

## 背景

`--web` 会在局域网内起一个 HTTP 服务，暴露一个可以删除本地分支和 worktree 的页面。绑定地址默认 `0.0.0.0`，端口由内核随机分配。服务是一次性的：处理完一批提交后即退出。

设计过程中确认了两条攻击路径：

1. **同网段任何人可访问。** 服务没有身份校验，知道 `IP:端口` 就能操作。
2. **跨站请求伪造（CSRF）。** 用户浏览的任意网页可以发一个 `<form action="http://192.168.110.17:PORT/delete" method="POST">`，借用户的浏览器发起删除请求。浏览器不拦这种跨源表单提交。

## 决定

两条路径都不做防护：没有认证，没有 CSRF token，也不校验 `Origin` / `Referer`。

## 为什么

**服务存活窗口极短。** 一次性会话意味着端口只在「启动 → 用户勾选 → 提交」这几分钟内开放，之后进程退出、端口释放。攻击者必须在这个窗口内猜中随机高端口，且受害者恰好在这个窗口内访问了恶意页面。

**这是一个单机开发者工具，不是服务。** 它运行在用户自己的机器上，删除的是本地分支——git 里被删的分支在 reflog 里还能找回（默认 90 天）。损失上限是「重新创建分支」的成本，不是数据丢失。

**保护规则在服务端强制执行。** 主干、当前分支、未推送 commit 都会被跳过（见 `CONTEXT.md` 的 Protected branch）。伪造请求即便到达服务端，也删不掉这些分支。剩下的可删分支，本身就是「远程已经不要了」的东西。

**认证会破坏主要使用场景。** 用户的典型流程是：SSH 到机器上跑命令，然后在同一局域网的手机或笔记本上打开链接操作。要求输密码、或者要求粘贴长 token，都会让"在网页上勾选"比原来的终端 y/N 更麻烦——那就没人会用这个功能了。

## 后果

- 必须只在可信局域网使用。不要把服务暴露到公网，不要在不受信任的网络（咖啡馆 Wi-Fi、公共热点）上启动。
- 页面顶部和终端启动横幅都有明确警告，不隐藏这个事实。
- 如果将来要支持跨不可信网络使用，需要重新设计：URL token 或 Basic Auth，并补上 `Origin` 校验。这不是「加一行」的改动，会改变使用流程，所以留作独立决策。
- `--bind` 可以让用户自己收紧到 `127.0.0.1` 或单个网卡地址。

## 验证方式（无自动化测试）

设计时选择不写自动化测试，理由是仓库里绝大多数工具都没有测试，而这个工具的核心风险在真实 git 状态而非纯函数逻辑。改动这个工具时应手工在临时仓库里覆盖：

```bash
TMP=$(mktemp -d) && cd "$TMP"
git init -q --bare origin.git && git clone -q origin.git work && cd work
git config user.email t@t && git config user.name T
echo a > f && git add f && git commit -qm init && git branch -m master
git push -q -u origin master

git checkout -q -b no-upstream && echo b > f && git commit -qam b   # 无上游
git checkout -q -b will-be-gone master
git push -q -u origin will-be-gone && git push -q origin --delete will-be-gone  # 远程已删
git checkout -q -b has-unpushed master && echo c > g && git add g && git commit -qm x  # 未推送
git checkout -q -b dirty-wt master
git worktree add -q ../wt-dirty dirty-wt && echo d >> ../wt-dirty/f   # 脏 worktree
git checkout -q master
```

要点：

- `--no-fetch --dry-run` 应只列出 `will-be-gone`；`no-upstream`、`has-unpushed` 因保护规则不应出现；`dirty-wt` 应出现并带「有未提交改动」警告。
- `--web` 启动后页面里受保护项应 `disabled`，`will-be-gone` 与 `dirty-wt` 应默认 `checked`。
- 有改动的分支行应有「查看改动」链接，`/diff?branch=<name>` 应列出改动文件与 diff，未跟踪文件内容也应显示。
- POST `branch=master&branch=<可删分支>` 时 master 必须被服务端跳过，只删后者。
- POST 后 worktree 目录应一并消失，`git worktree list` 只剩主仓库。
- 分支名含 `<script>` 时页面应显示转义文本，不得执行。
- `--port` 指向已占用端口时，应打印回落提示并换成随机端口。
- 点页面「退出」（或 `curl -X POST /quit`）后进程应在数秒内退出、端口释放，且不删除任何分支。
