# MoonBit IRC 协议核心与客户端 · 项目申报书

## 一、项目名称

MoonBit IRC 协议核心与客户端

## 二、项目说明

MoonBit 实现消息、IRCv3 tags、增量行解析、CAP 302 和注册会话；Node 24 提供 TCP/TLS、自动 PONG、有界重连及 SASL PLAIN 交换。

## 三、方向与通用性

基础软件与聊天协议。用于机器人接入、私有服务器认证及 IRC 教学；未实现完整频道状态缓存、其他 SASL 机制或全部 IRCv3 扩展。

## 四、应用场景

connect 在收到 001 后完成，应用显式 JOIN/发言；配置 SASL 后必须认证成功，不降级匿名；断线后按有限次数重建会话，未发请求不自动补发。

## 五、功能与验证边界

已保存 11 项回环网络检查和 Ergo 2.19.1 的 6 项互通记录，覆盖 TLS、认证、中文拆包等选定路径。凭证只经验证成功的 TLS 发送；不承诺内存安全擦除或长期无人值守可靠性。

## 六、原创性与参考材料

原创代码 MIT。依据 https://modern.ircdocs.horse/ 与 https://ircv3.net/specs/extensions/capability-negotiation.html 实现，探针自写；Ergo（MIT，https://github.com/ergochat/ergo/blob/master/LICENSE）是独立测试服务端，二进制不随源码分发。

## 七、仓库链接

https://github.com/chenglong-coding/moonbit-irc
