///|
test "tags prefix trailing and canonical serialization" {
  let m = @irc.parse(
    "@aaa=hello\\sworld;flag :nick!u@host PRIVMSG #test :hello there\r\n",
  )
  assert_eq(m.command, "PRIVMSG")
  assert_eq(m.prefix, Some("nick!u@host"))
  assert_eq(m.params, ["#test", "hello there"])
  assert_eq(m.tags[0].value, Some("hello world"))
  assert_eq(m.tags[1].value, None)
  assert_eq(@irc.parse(m.encode()), m)
}

///|
test "duplicate tags last wins unknown escapes disappear" {
  let m = @irc.parse("@x=first;x=a\\qb\\:c\\ PING :")
  assert_eq(m.tags.length(), 1)
  assert_eq(m.tags[0].value, Some("aqb;c"))
  assert_eq(m.params, [""])
}

///|
test "byte fragmentation and coalescing" {
  let line = b":server 001 nick :Welcome\r\nPING :server\r\n"
  let d = @irc.Decoder::new()
  let messages = []
  for b in line {
    for m in d.feed(Bytes::from_array([b])) {
      messages.push(m)
    }
  }
  assert_eq(messages.length(), 2)
  assert_eq(messages[0].command, "001")
  d.finish()
}

///|
test "reject injection malformed and oversize" {
  for
    s in [
      "", ":x", "@x", "PR1VMSG x", "PING a\r\nQUIT", "PING \u0000", ": PING",
    ] {
    assert_true(
      try {
        ignore(@irc.parse(s))
        false
      } catch {
        _ => true
      },
    )
  }
  let m : @irc.Message = {
    tags: [],
    prefix: None,
    command: "PING",
    params: ["bad\r\nQUIT"],
  }
  assert_true(
    try {
      ignore(m.encode())
      false
    } catch {
      _ => true
    },
  )
  let d = @irc.Decoder::new()
  assert_true(
    try {
      ignore(d.feed(b"PING\n"))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      d.finish()
      false
    } catch {
      _ => true
    },
  )
}
