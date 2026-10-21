# CPR 真实验收：地址范围更正与交接

## 结论

**目标 HTTPS CPR 入口仍未完成真实工具调用验收，v0.1.0 保留预发布状态。**

2026-10-22 00:36（香港时间）核对原生配置及两次自检的 `state.json` 后发现：**旧测试连接的是维护机内网 HTTP API，而不是安装器固定的 `https://cpr.molaisonz.dpdns.org/v1`。** 本页 10 月 21 日曾将这两次失败归到 HTTPS 入口，现更正这一归因；失败记录本身有效，但仅适用于原测试地址。

已从原会话引用的前序记录恢复**现有 ywl 内网 provider、`auth.command` 和官方客户端隔离环境**。这份配置及凭据可继续用于原地址验收，不需要用户重新提供。2026-10-22 已复用它完成一次新的真实只读调用，结果仍为 `UPSTREAM_READINESS`。当前内网路由的阻塞是上游 readiness，而不是缺少配置；HTTPS 入口仍需独立验证，不能直接沿用内网结果或未经绑定跨地址发送 Key。

已完成的跨平台离线测试和发行包核对见 [README](../README.md#测试状态)。本次诊断修正的相关 53 项离线测试通过，另外已用真实旧记录确认输出正确的内网 `endpoint`。离线测试不证明 CPR 工具调用可用，也不代替 Windows、macOS、Linux 的独立用户环境验收。

## 本次 HTTPS 入口检查

- 公开页面可访问，标题为 `Codex Proxy RS`；页面可访问不代表模型请求可用。
- 未携带 Key 的 `GET /v1/models` 返回 HTTP **401**，错误为 `Missing or invalid API key`。这是预期鉴权拒绝，不证明个人 Key 无效或模型服务故障。
- 已检查的原隔离环境及维护机当前原生配置指向内网地址；没有发现已绑定目标 HTTPS 字符串的连接。这不等于没有可用 CPR 凭据，也不应阻止继续验收原内网配置。未把内网凭据发往未经验证的 HTTPS 地址。
- 本次没有在 HTTPS 地址发起官方客户端真实工具自检；尚无该 HTTPS 地址上的 `[READY]` 或已鉴权模型失败证据。下节新增调用使用的是已恢复的原内网配置。

## 内网测试的有效证据范围

- 原测试服务：维护机内网 HTTP API（`http://<内网地址>:18082/v1`，此处脱敏；精确地址见原始 `state.json` 的 `connection.url`）。**不是目标 HTTPS 入口。**
- 客户端：经官方 npm SHA512 校验的原版 Codex **0.162.1**，Linux x64。
- 模型：`chatgpt-web/gpt-6-tools-temp`；使用已保存的原生配置。
- 前置结果：该内网地址此前 `/models` 权限检查通过；本地维护目录有 9 个可见的 V1 模型。这些结果不能外推到 HTTPS 入口。
- 自检任务：只读取隔离工作目录中的临时文件，要求工具输出与最终回答逐字匹配。

| 香港时间 | 时长 | 原生终态 | 完成的工具项 / 成功回合 |
| --- | --- | --- | --- |
| 2026-10-21 20:04:43–20:18:32 | 829 秒 | `terminal`，退出码 1 | 0 / 0 |
| 2026-10-21 21:06:51–21:20:42 | 830 秒 | `terminal`，退出码 1 | 0 / 0 |
| 2026-10-22 00:57:09–01:11:52 | 883 秒 | `terminal`，退出码 1 | 0 / 0 |

三次记录均被安装器归类为 `UPSTREAM_READINESS`，均没有 `final.txt`。每份事件流中都观察到 14 条包含下述错误的事件；**这是事件条数，不代表 14 次独立请求或 14 个账号**：

```text
ChatGPT personalization preflight exceeded its readiness deadline
```

该证据定位到**内网请求**报告的 readiness 阶段，尚不足以判断是账号、浏览器会话、桥接组件还是其他内部故障，也不足以证明另一地址有同一故障。第三次调用沿用原配置、原模型和原版官方客户端，只发起一次；结束后已确认 worker/client 均不再运行，没有连续重投，也没有重启共享服务。

## 维护机上的原始证据

私有目录仅供原维护者检查，不应整体上传或转发：

```text
/tmp/codex101-official-live-probe/provider-connect/checks/attempt-eujkzjrc/
/tmp/codex101-official-live-probe/provider-connect/checks/attempt-xstekuti/
/tmp/codex101-official-live-probe/provider-connect/checks/attempt-m_xf3n7q/
```

每个目录的 `state.json` 记录生命周期、客户端路径和退出码；`events.jsonl` 保存失败事件。`/tmp` 是易失存储，重启或清理后可能消失；上表是本次已脱敏保留的复核结果，不代表原始日志永久可用。

不发请求、只查询原生判定的命令（在维护机仓库根运行）：

```bash
python3.11 - <<'PY'
from pathlib import Path
import json
from codex_provider import check_result

root = Path('/tmp/codex101-official-live-probe/provider-connect/checks')
for directory in sorted(root.glob('attempt-*')):
    print(directory.name, json.dumps(check_result(directory), ensure_ascii=False))
PY
```

不要提供 Key、私有 Key 文件、整个 `config.toml` 或整个 `CODEX_HOME`。对外反馈可直接使用本页的时间、模型、错误和终态。

## 诊断修正与发行版边界

当前修正源码的自检诊断增加 `endpoint`，标明该次记录的连接地址；待完成、成功、失败和输出不匹配都带此字段。旧记录没有地址时明确返回 `null`，不猜测。安装报告和 `doctor --json` 也标明所检连接；连接变化时同时给出原地址与新地址。不改变真实调用或 `[READY]` 的验收条件。

这项修正**尚未包含在既有 v0.1.0 Release 附件中**。旧版本维护者仍需核对 `state.json` 的 `connection.url` 与原生配置中的 `base_url`，不能只看模型名或错误码。

## 恢复条件与下一步

1. **CPR 服务/账号维护者**：根据第三次调用的时间窗及错误检查该内网路由的 Web personalization readiness。现有配置和凭据已经恢复，不再把用户重新提供配置或 Key 当作排查前置。不得为排查强制重启别人的活跃任务；远程生产变更仍需对应授权。
2. **仓库维护者**：上游恢复后，沿用现有 `auth.command` 和同地址配置，在原隔离环境仅恢复或发起一次必要的真实只读自检。只有文件读取、内容匹配、成功回合及退出码全部满足，才接受该地址的 `[READY]`；不连续重投、不换模型冒充修复。
3. **HTTPS 入口维护者**：通过已有部署配置或原生管理机制核实 HTTPS 路由及凭据绑定，再独立验证 HTTPS 入口。当前没有证明两地址属于同一部署的运行时映射，因此不盲目把内网 Key 转发过去，也不以此向用户反复索要相同信息。
4. **各平台试用者**：分别在 Windows、macOS、Linux 独立用户环境运行 Release 安装器并取得本机 `[READY]`。三平台实机验收完成前，不转为稳定版或宣布全平台可用。

客户端重试字段的定义见 [OpenAI Codex 配置参考](https://developers.openai.com/codex/config-reference/)（2026-10-21 已读取核实）；这些配置不是 CPR 内部故障的诊断依据。
