///|
test "CAP 302 multiline LS is atomic with values and duplicate precedence" {
  let caps = @irc.Capabilities::new()
  caps.observe(@irc.parse("CAP * LS * :multi-prefix sasl=PLAIN"))
  assert_false(caps.listing_complete())
  assert_false(caps.available("multi-prefix"))
  caps.observe(@irc.parse("CAP * LS :sasl=PLAIN,EXTERNAL server-time"))
  assert_true(caps.listing_complete())
  assert_true(caps.available("multi-prefix"))
  assert_eq(caps.value("sasl"), Some("PLAIN,EXTERNAL"))
  assert_true(caps.enabled("cap-notify"))
  assert_false(caps.enabled("multi-prefix"))
}

///|
test "requests wait for ACK and NAK does not change capabilities" {
  let caps = @irc.Capabilities::new()
  caps.observe(@irc.parse("CAP * LS :multi-prefix server-time"))
  assert_eq(
    caps.request(["multi-prefix", "server-time"]).encode(),
    "CAP REQ :multi-prefix server-time\r\n",
  )
  assert_false(caps.enabled("server-time"))
  caps.observe(@irc.parse("CAP * NAK :multi-prefix server-time"))
  assert_false(caps.enabled("multi-prefix"))
  caps.observe(@irc.parse("CAP * ACK :multi-prefix server-time"))
  assert_true(caps.enabled("server-time"))
  caps.observe(@irc.parse("CAP * ACK :-server-time"))
  assert_false(caps.enabled("server-time"))
}

///|
test "NEW updates opaque values and DEL cancels enabled capability" {
  let caps = @irc.Capabilities::new()
  caps.observe(@irc.parse("CAP * LS :sasl=PLAIN"))
  caps.observe(@irc.parse("CAP nick NEW :sasl=PLAIN,EXTERNAL vendor/x=a=b"))
  assert_eq(caps.value("vendor/x"), Some("a=b"))
  assert_eq(caps.value("sasl"), Some("PLAIN,EXTERNAL"))
  caps.observe(@irc.parse("CAP nick ACK sasl"))
  caps.observe(@irc.parse("CAP nick DEL sasl"))
  assert_false(caps.available("sasl"))
  assert_false(caps.enabled("sasl"))
}

///|
test "LIST replaces rather than appends and empty LS is valid" {
  let caps = @irc.Capabilities::new()
  caps.observe(@irc.parse("CAP * LS :"))
  assert_true(caps.listing_complete())
  caps.observe(@irc.parse("CAP x ACK old"))
  caps.observe(@irc.parse("CAP x LIST * :new"))
  assert_true(caps.enabled("old"))
  assert_false(caps.enabled("new"))
  caps.observe(@irc.parse("CAP x LIST :other"))
  assert_false(caps.enabled("old"))
  assert_true(caps.enabled("new"))
  caps.observe(@irc.parse("CAP x LIST :"))
  assert_false(caps.enabled("new"))
  assert_true(caps.enabled("cap-notify"))
}

///|
test "multiline ACK applies only on final line" {
  let caps = @irc.Capabilities::new()
  caps.observe(@irc.parse("CAP * ACK * :one"))
  assert_false(caps.enabled("one"))
  caps.observe(@irc.parse("CAP * ACK :two"))
  assert_true(caps.enabled("one"))
  assert_true(caps.enabled("two"))
}

///|
test "invalid CAP updates preserve state and can be retried" {
  let caps = @irc.Capabilities::new()
  caps.observe(@irc.parse("CAP * LS * :good"))
  for line in ["CAP * LS :ok -bad", "CAP * LS wrong :ok"] {
    assert_true(
      try {
        caps.observe(@irc.parse(line))
        false
      } catch {
        _ => true
      },
    )
  }
  caps.observe(@irc.parse("CAP * LS :last"))
  assert_true(caps.available("good"))
  assert_false(caps.available("ok"))
  assert_true(caps.available("last"))
}

///|
test "request injection unknown names and forbidden cap-notify disable" {
  let caps = @irc.Capabilities::new()
  caps.observe(@irc.parse("CAP * LS :known"))
  for
    names in [
      [],
      ["absent"],
      ["known\r\nQUIT"],
      ["known extra"],
      ["known=value"],
      ["-cap-notify"],
    ] {
    assert_true(
      try {
        ignore(caps.request(names))
        false
      } catch {
        _ => true
      },
    )
  }
}

///|
test "capability names remain case sensitive and unrelated messages ignored" {
  let caps = @irc.Capabilities::new()
  caps.observe(@irc.parse("CAP * LS :Case case="))
  caps.observe(@irc.parse("PING token"))
  assert_true(caps.available("Case"))
  assert_false(caps.available("CASE"))
  assert_eq(caps.value("Case"), None)
  assert_eq(caps.value("case"), Some(""))
}

///|
test "capability continuation resource bounds" {
  let caps = @irc.Capabilities::new()
  for _ in 0..<512 {
    caps.observe(@irc.parse("CAP * LS * :same"))
  }
  assert_true(
    try {
      caps.observe(@irc.parse("CAP * LS * :overflow"))
      false
    } catch {
      _ => true
    },
  )
  caps.observe(@irc.parse("CAP * LS :"))
  assert_true(caps.available("same"))
  assert_false(caps.available("overflow"))
}

///|
test "capability notification can interleave with multipart ACK" {
  let caps = @irc.Capabilities::new()
  caps.observe(@irc.parse("CAP * ACK * :one"))
  caps.observe(@irc.parse("CAP * NEW :new=value"))
  assert_true(caps.available("new"))
  assert_false(caps.enabled("one"))
  caps.observe(@irc.parse("CAP * ACK :two"))
  assert_true(caps.enabled("one"))
}
