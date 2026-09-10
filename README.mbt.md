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

限制：协议消息核心；不含重连、TLS、CAP 协商与网络客户端。
