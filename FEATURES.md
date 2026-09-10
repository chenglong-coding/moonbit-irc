# 功能与兼容性边界

## 新增能力

增加 PING 到 PONG 的响应接口，修复非法 UTF-16 崩溃。

## 尚未达到上游的部分

尚无 SASL EXTERNAL/SCRAM 与 SASLprep、频道成员/模式缓存、自动重加入和长期多服务端验证；目前仅支持 PLAIN 认证机制。已有基础能力参见 README 与生成的 `pkg.generated.mbti`。

## 工程交付范围

独立 Git 仓库、独立构建目录、可执行文档、Wasm-GC/JS 测试、真实编译的浏览器与 CLI、边界输入检查、样例基准、CI 配置均随仓库交付。运行记录见 evidence；配置 CI 不代表远端 CI 已运行。没有公开发布或比赛验收结论。


新增 MoonBit CAP 302 状态：多行 LS/LIST/ACK 原子更新、能力值、REQ、NAK、NEW/DEL 和资源边界。

规范：[IRCv3 Capability Negotiation](https://ircv3.net/specs/extensions/capability-negotiation.html)。新增 10 组按规范编写的测试；另已通过 Ergo 2.19.1 本地 TLS/SASL/消息互通；仍不宣称全部 IRC 客户端行为兼容。


0.4.0 新增 MoonBit 注册/协商会话和 Node TCP/TLS 客户端：自动 PONG、CAP 选择与等待确认、注册拒绝、超时、有上限的重连、收发缓冲限制。


0.5.0 新增服务器 PASS 与必需 SASL PLAIN 认证：CAP 确认后发送凭证，400 字节分块、等待 903、拒绝匿名降级。Node 认证连接要求 TLS。
