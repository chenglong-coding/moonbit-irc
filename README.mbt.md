# 可执行 API 示例

增加 PING 到 PONG 的响应接口，修复非法 UTF-16 崩溃。这些例子调用公开 API，并随 `moon test` 执行。

```mbt check
///|
test "PING matching PONG" {
  let m = @irc.parse("PING :server.example\r\n")
  let p = m.pong()
  assert_eq(p.command, "PONG")
  assert_eq(p.params, ["server.example"])
  assert_eq(@irc.parse(p.encode()), p)
  assert_true(
    try {
      ignore(@irc.parse("QUIT :bye\r\n").pong())
      false
    } catch {
      _ => true
    },
  )
}
```

限制：尚无 SASL EXTERNAL/SCRAM 与 SASLprep、频道成员/模式缓存、自动重加入和长期多服务端验证；目前仅支持 PLAIN 认证机制。


新增 MoonBit CAP 302 状态：多行 LS/LIST/ACK 原子更新、能力值、REQ、NAK、NEW/DEL 和资源边界。

规范：[IRCv3 Capability Negotiation](https://ircv3.net/specs/extensions/capability-negotiation.html)。新增 10 组按规范编写的测试；另已通过 Ergo 2.19.1 本地 TLS/SASL/消息互通；仍不宣称全部 IRC 客户端行为兼容。

```mbt check
///|
test "CAP negotiation lifecycle" {
  let caps = @irc.Capabilities::new()
  caps.observe(@irc.parse("CAP * LS :server-time"))
  let request = caps.request(["server-time"])
  assert_eq(request.command, "CAP")
  assert_false(caps.enabled("server-time"))
  caps.observe(@irc.parse("CAP * ACK server-time"))
  assert_true(caps.enabled("server-time"))
  caps.observe(@irc.parse("CAP nick DEL server-time"))
  assert_false(caps.enabled("server-time"))
}
```

接入时发送 `CAP LS 302` 和 NICK/USER，逐条调用 `observe`；`listing_complete` 后选择能力并发送 `request` 结果。等待 ACK 与应用层认证完成后发送 `CAP END`。不支持 CAP 的服务器、超时与连接重置由宿主管理；每次新连接创建新实例。网页和 CLI 目前提供消息解析入口，新状态 API 如上调用。


0.4.0 新增 MoonBit 注册/协商会话和 Node TCP/TLS 客户端：自动 PONG、CAP 选择与等待确认、注册拒绝、超时、有上限的重连、收发缓冲限制。


0.5.0 新增服务器 PASS 与必需 SASL PLAIN 认证：CAP 确认后发送凭证，400 字节分块、等待 903、拒绝匿名降级。Node 认证连接要求 TLS。
