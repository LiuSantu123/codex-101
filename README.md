# codex-101 · 实验室 Codex 安装与使用

**每位同学只需要自己的 CPR API Key。** 在 Windows、macOS、Linux **本机**运行安装命令；不用 SSH 到 ywl，不必手工写 `config.toml`，不用自己安装 Node.js/npm。

> **版本状态：v0.1.0 首发候选**。仅收到 `[READY]` 且安装程序成功退出，才能认定**自己这台机器**的模型、凭据和真实工具调用已通过。管理员发布前/验证记录详见 [测试状态](#测试状态)。

## 一键安装

先联系 **@曾正鹏** 获取个人 Key。Key 有个人配额，请保密。**不要**把 Key 发给聊天机器人、粘贴进命令行参数或保存到 Git。

**Windows（PowerShell）** — 将整行复制到 PowerShell：

```powershell
& ([scriptblock]::Create((Invoke-WebRequest -UseBasicParsing 'https://github.com/Molaison/codex-101/releases/download/v0.1.0/install.ps1').Content)) -Lab
```

**macOS（终端 Terminal）**：

```bash
(set -o pipefail; curl --http1.1 -fsSL --retry 2 https://github.com/Molaison/codex-101/releases/download/v0.1.0/install.sh | bash -s -- --lab)
```

**Linux（终端）**：

```bash
(set -o pipefail; curl --http1.1 -fsSL --retry 2 https://github.com/Molaison/codex-101/releases/download/v0.1.0/install.sh | bash -s -- --lab)
```

输入个人 Key 时，终端不会显示输入内容。安装器会使用固定的 CPR 地址、在用户目录安装**未经修改的官方 Codex**、合并配置、保留旧客户端与会话，并进行**真实文件读取工具测试**。成功后打开新终端：

```bash
cd <你的项目目录>
codex
```

遇到已有定制版客户端抢占 `codex` 命令名时，使用安装器输出的实验室官方路径：Windows 为 `%LOCALAPPDATA%\CodexLab\bin\codex.cmd`，macOS/Linux 为 `~/.local/share/codex-lab/bin/codex`。已有配置/正在运行的任务不会被强行清理或覆盖。

## 默认配置

| 项目 | 本仓库默认行为 |
| --- | --- |
| 服务 | `https://cpr.molaisonz.dpdns.org/v1`（需要从当前网络访问该域名） |
| 模型 | `chatgpt-web/gpt-6-tools-temp`，**GPT-6 Web Tools Temporary** |
| 权限 | `danger-full-access`、`approval_policy=never`（按实验室要求，**不会询问执行批准**） |
| 稳定性 | **SSE**，HTTP 请求最多重试 **8 次**；SSE 中断最多重试 **12 次**；SSE 空闲超时 **15 分钟** |
| 存储 | 本机用户私有临时目录存 SQLite；保留原 `CODEX_HOME`、sessions；不覆盖运行中的数据库 |
| 凭据 | 独立私有 Key 文件，使用 `auth.command`；不同服务地址不交叉复用 Key |
| 模型目录 | **V1-only**，普通菜单保留 9 个经维护目录标注的模型，隐藏内部保留 2 个 |

⚠️ **全权限模式能操作你有权访问的任何文件，包括共享目录。** 请从正确的项目目录启动，并先备份重要数据。Linux/macOS 终端需要 `curl` 和 Python 3.8+；Windows 脚本可在用户目录安装自带 Python，不需要管理员权限。`/tmp` / 系统临时目录里的 SQLite 不适合作为长期唯一数据存储。

## 模型选择、配置细节与故障排查

完整中文说明：[**安装教程与 GPT 模型用途对照**](docs/installation.md)。在 Codex 中输入 `/model` 选择模型；显示名 **不是** API ID。`Tools` 是完整的 Codex 工具模式，适合改代码、读文件（上下文偏编程）；`Chat` 更偏一般问答。`Temporary` **不会保存到 Web 账号聊天历史**，更少留痕，但日后可能找不回该 Web 会话；`Persist` 保留 Web 聊天历史，便于回查。临时模式不等于服务端零留存，且与本地 Codex sessions 是两回事。上游原生 GPT 的 Sol/Astra/Luna 等系列也有说明，但当前不符合 V1-only 的不会出现在模型菜单。

出现 `Reconnecting...`：先确认上游回合是否终止；已提交的回合不能仅因前台断线而重复执行。重跑安装命令只恢复尚未完成的自检，不强制重启正在忙的服务。

## 测试状态

**v0.1.0 已作为 pre-release 发布，尚不是实机验证通过的稳定版。** 2026-10-21 的 [GitHub Actions 跨平台测试](https://github.com/Molaison/codex-101/actions/runs/39603874786) 已全部成功（Windows、macOS、Ubuntu）；Linux 本地 84 项离线测试通过。发行包四个文件已从公开 Release 重新下载并与源码逐一比对一致。

**真实 CPR 验收仍未通过**：维护环境使用经官方 npm SHA512 校验的原版 Codex 0.162.1，`/models` 预检成功，9 个 V1 模型菜单可加载；两次独立真实只读工具调用均在 CPR 上游返回 `ChatGPT personalization preflight exceeded its readiness deadline`，终态为 `UPSTREAM_READINESS`，**没有 `[READY]`**。需要 CPR 桥接/账号会话维护者排查 readiness 后，再完成端到端验收。不得把菜单加载、离线 CI 或首次请求成功当成工具调用成功。

**离线测试不能替代本人 Key 的端到端测试。** CPR `/models` 可用只证明模型权限；仅使用最终安装的官方客户端成功读取文件并返回匹配内容，才能打印 `[READY]`。

本仓库从维护者的 [codex-provider-connect](https://github.com/Molaison/codex-provider-connect) 接入器演进而来，`codex_provider.py` 仍保留兼容入口。发行版锁定一个版本的 Shell / PowerShell 启动器、Python 助手和 V1 模型目录。
