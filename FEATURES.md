# 功能与兼容性边界

## 新增能力

增加 PING 到 PONG 的响应接口，修复非法 UTF-16 崩溃。

## 尚未达到上游的部分

仍不含 socket/TLS、自动重连、SASL 认证和完整网络客户端；CAP END 与注册时机由调用方控制。已有基础能力参见 README 与生成的 `pkg.generated.mbti`。

## 工程交付范围

独立 Git 仓库、独立构建目录、可执行文档、Wasm-GC/JS 测试、真实编译的浏览器与 CLI、边界输入检查、样例基准、CI 配置均随仓库交付。运行记录见 evidence；配置 CI 不代表远端 CI 已运行。没有公开发布或比赛验收结论。


新增 MoonBit CAP 302 状态：多行 LS/LIST/ACK 原子更新、能力值、REQ、NAK、NEW/DEL 和资源边界。

规范：[IRCv3 Capability Negotiation](https://ircv3.net/specs/extensions/capability-negotiation.html)。新增 10 组按规范编写的测试；未做真实 IRC 服务器互操作，不能据此宣称完整客户端兼容。
