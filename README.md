# IRCv3 协商与 TLS/SASL 会话核心

**本项目仓库：[https://github.com/chenglong-coding/moonbit-irc](https://github.com/chenglong-coding/moonbit-irc)**

模块 `chenglong-coding/irc`，本地版本 **0.5.0**，MIT。当前评审状态：**暂缓复申**。本文件是当前入口，旧轮次说明与详细用法保存在 [历史/完整使用说明](README-BEFORE-VALUE-REWORK.md)。

## 解决什么任务

为私有 IRC 服务上的通知机器人提供注册、CAP 协商、分包消息、TLS/SASL 与受限重连；由应用明确决定加入频道和发送消息。

保留为 IRC 协议组件；如果没有确实使用 IRC 服务的调用方，不把一般“通知机器人”作为选择 IRC 的充分理由。

## 直接复现

安装 MoonBit 和 Node.js 24，在本仓库根目录运行：

```sh
moon build --target js
node -e "require('node:fs').copyFileSync('_build/js/debug/build/cmd/web/web.js','web/engine.mjs')"
node examples/run-use-case.mjs
```

流程：**保留 IRCv3 tags 的报文读取**。运行器创建新的系统临时目录，保留每一步的 stdout/stderr、产物及 `report.json`，打印实际目录；重复运行不会覆盖之前产物。它只执行仓库内的本地样例，不连接公网或发送消息。`report.json` 的 `expected` 是应观察的结果，实际结果在各步输出中；成功退出不替代内容核对。

输入性质：离线合成消息；仅保留库用法，不将其作为已经解决选题价值问题的证明。

应观察：解析 tags/prefix/params 并重编码；不会向任何频道发送消息。

具体命令和输入路径见 [使用任务](USE-CASE.md) 与 [机器可读流程](examples/use-case.json)。只把这个脚本当复现入口，不把通用运行器计作核心技术贡献。

## 实现与已有项目的关系

MoonBit 负责行解析、tags、CAP302、注册与 PLAIN 分段认证状态；Node 处理 socket、TLS、时钟及重连。

本轮未找到同范围 MoonBit IRCv3 客户端。价值是可复用协议状态和可运行连接流程，不是新协议或全生态首次通信程序。

同类项目和检索边界见 [DUPLICATION](DUPLICATION.md)。查重用于避免错误的首创表述；关键词零结果不能证明生态空白，Node 宿主能力也不计为 MoonBit 原生 I/O。

库使用从 [公共 API](pkg.generated.mbti) 和根包源码开始；可在本 checkout 的消费包中导入 `"chenglong-coding/irc"`。源码中的网络/文件宿主入口及完整参数仍见 [完整使用说明](README-BEFORE-VALUE-REWORK.md)。是否已发布到 Mooncakes 需另核实，本文不把 `moon add` 的下载成功作为已完成事项。

## 验证与边界

前一轮工程验证本机 TCP/TLS 11 项检查通过；历史 Ergo2.19.1 互通报告是另外的固定版本证据。

[上一轮工程验证](evidence/innovation-review-20260922/results.json) 与 [本轮最小任务回执](evidence/value-rework-20260922/use-case.json) 分开。历史参考版本、golden 重放、本机 peer、真实第三方服务端和本次样例是不同证据，不能合并成“全部生产验证”。

常规核心检查可运行 `moon check --target js`、`moon test --target js`、`moon test --target wasm-gc`。专项命令：

```sh
node tools/test-network.mjs
```

专项所需的参考环境和历史版本见原使用说明及 TESTING 文档；本轮回执只记录实际执行项，不声称上面所有参考服务在任意环境即装即跑。

只有 SASL PLAIN，无 EXTERNAL/SCRAM、完整频道状态及自动重加入；未证明长期生产稳定性。

## 复审材料状态

已收到选题过窄、价值有限的初审反馈；本轮无新增使用方依据，不通过扩大宣传解除该问题。

2026-09-22 匿名新克隆成功；默认分支 `main`，核验公开提交 `119a9fa1e86b0fad8e083adea1ac63e96464d262`。本轮源码修订仅在本地，尚未推送；此记录不证明当时报名表中的地址正确，也不证明新修订已上线。

[申报草稿](PROPOSAL.md) 已压缩为 30 行以内，并单独标明本项目仓库；[复核说明](REVIEW-RESPONSE.md) 区分材料错误、功能变化及尚未解决的问题。没有编造用户、设备接入、生产部署或评审认可。
