# 功能与兼容性边界

## 新增能力

增加 PING 到 PONG 的响应接口，修复非法 UTF-16 崩溃。

## 尚未达到上游的部分

尚无 SASL/PASS 认证、频道成员/模式缓存、自动重加入和长期真实 IRC 服务端互操作；Node 宿主提供网络，Wasm-GC 核心仍由宿主接入传输。已有基础能力参见 README 与生成的 `pkg.generated.mbti`。

## 工程交付范围

独立 Git 仓库、独立构建目录、可执行文档、Wasm-GC/JS 测试、真实编译的浏览器与 CLI、边界输入检查、样例基准、CI 配置均随仓库交付。运行记录见 evidence；配置 CI 不代表远端 CI 已运行。没有公开发布或比赛验收结论。


新增 MoonBit CAP 302 状态：多行 LS/LIST/ACK 原子更新、能力值、REQ、NAK、NEW/DEL 和资源边界。

规范：[IRCv3 Capability Negotiation](https://ircv3.net/specs/extensions/capability-negotiation.html)。新增 10 组按规范编写的测试；未做真实 IRC 服务器互操作，不能据此宣称完整客户端兼容。


0.4.0 新增 MoonBit 注册/协商会话和 Node TCP/TLS 客户端：自动 PONG、CAP 选择与等待确认、注册拒绝、超时、有上限的重连、收发缓冲限制。
