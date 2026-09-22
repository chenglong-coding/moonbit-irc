# 保留 IRCv3 tags 的报文读取

为私有 IRC 服务上的通知机器人提供注册、CAP 协商、分包消息、TLS/SASL 与受限重连；由应用明确决定加入频道和发送消息。

## 输入、操作、输出

离线合成消息；仅保留库用法，不将其作为已经解决选题价值问题的证明。

最简运行：先按 README 构建，然后 `node examples/run-use-case.mjs`。它自动创建输出目录并执行下面命令。下列 `{out}` 是运行器替换的实际目录，不是直接输入 shell 的变量；stdin 文件由运行器传递，以避免 Windows 与 POSIX 重定向差异。

```text
node tools/cli.mjs --file examples/use-case/message.txt
```

观察：解析 tags/prefix/params 并重编码；不会向任何频道发送消息。

每一步输出见实际目录下 `step-N.stdout.txt` / `step-N.stderr.txt`；本轮已保存回执见 `evidence/value-rework-20260922/use-case.json`。

## 为什么保留这个实现

保留为 IRC 协议组件；如果没有确实使用 IRC 服务的调用方，不把一般“通知机器人”作为选择 IRC 的充分理由。

本轮未找到同范围 MoonBit IRCv3 客户端。价值是可复用协议状态和可运行连接流程，不是新协议或全生态首次通信程序。

## 不能由样例推出的结论

只有 SASL PLAIN，无 EXTERNAL/SCRAM、完整频道状态及自动重加入；未证明长期生产稳定性。

该样例是可修改的使用入口，不能证明存在真实用户、全部兼容或性能领先。继续投入的依据应是明确的输入或接入需求；若对接任务用既有成熟库即可完成，应优先复用而不是为保留参赛数量扩张本项目。
