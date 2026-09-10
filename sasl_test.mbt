///|
test "SASL PLAIN official exchange and PASS ordering" {
  let auth = @irc.SaslPlain::new("jilles", "sesame", authorization_id="jilles")
  let s = @irc.Session::new([], plain=Some(auth))
  let start = s.start("jilles", "u", "r", server_password=Some("server-secret"))
  assert_eq(start[0].encode(), "PASS server-secret\r\n")
  assert_eq(start[1].params, ["LS", "302"])
  assert_eq(s.receive(@irc.parse("CAP * LS :sasl=PLAIN,EXTERNAL"))[0].params, [
    "REQ", "sasl",
  ])
  assert_eq(s.receive(@irc.parse("CAP * ACK sasl"))[0].params, ["PLAIN"])
  assert_eq(s.receive(@irc.parse("AUTHENTICATE +"))[0].params, [
    "amlsbGVzAGppbGxlcwBzZXNhbWU=",
  ])
  assert_eq(s.receive(@irc.parse("900 jilles host account :logged in")), [])
  assert_eq(s.status(), "negotiating")
  assert_eq(s.receive(@irc.parse("903 jilles :success"))[0].params, ["END"])
  ignore(s.receive(@irc.parse("001 jilles :welcome")))
  assert_eq(s.status(), "registered")
}

///|
test "SASL PLAIN exact 400 byte boundary requires plus terminator" {
  let s = @irc.Session::new(
    [],
    plain=Some(@irc.SaslPlain::new("u", "p".repeat(297))),
  )
  ignore(s.start("n", "u", "r"))
  ignore(s.receive(@irc.parse("CAP * LS :sasl")))
  ignore(s.receive(@irc.parse("CAP * ACK sasl")))
  let chunks = s.receive(@irc.parse("AUTHENTICATE +"))
  assert_eq(chunks.length(), 2)
  assert_eq(chunks[0].params[0].length(), 400)
  assert_eq(chunks[1].params, ["+"])
}

///|
test "SASL unavailable denied and premature welcome fail closed" {
  for
    response in [
      "CAP * LS :", "CAP * LS :sasl=EXTERNAL", "001 n :welcome", "421 n CAP :unknown",
    ] {
    let s = @irc.Session::new([], plain=Some(@irc.SaslPlain::new("u", "p")))
    ignore(s.start("n", "u", "r"))
    assert_true(
      try {
        ignore(s.receive(@irc.parse(response)))
        false
      } catch {
        _ => true
      },
    )
    assert_eq(s.status(), "failed")
  }
  for
    response in [
      "CAP * NAK sasl", "902 n :locked", "904 n :failed", "905 n :long", "906 n :aborted",
      "907 n :already", "903 n :unexpected",
    ] {
    let s = @irc.Session::new([], plain=Some(@irc.SaslPlain::new("u", "p")))
    ignore(s.start("n", "u", "r"))
    ignore(s.receive(@irc.parse("CAP * LS :sasl")))
    assert_true(
      try {
        ignore(s.receive(@irc.parse(response)))
        false
      } catch {
        _ => true
      },
    )
    assert_eq(s.status(), "failed")
  }
}

///|
test "SASL credentials are validated without leaking their contents" {
  for
    (user, pass) in [
      ("", "p"),
      ("u", ""),
      ("u\u0000x", "p"),
      ("u", "p".repeat(4097)),
    ] {
    assert_true(
      try {
        ignore(@irc.SaslPlain::new(user, pass))
        false
      } catch {
        _ => true
      },
    )
  }
}

///|
test "SASL success waits for other requested capability ACK" {
  let s = @irc.Session::new(
    ["other"],
    plain=Some(@irc.SaslPlain::new("u", "p")),
  )
  ignore(s.start("n", "u", "r"))
  ignore(s.receive(@irc.parse("CAP * LS :sasl other")))
  ignore(s.receive(@irc.parse("CAP * ACK sasl")))
  ignore(s.receive(@irc.parse("AUTHENTICATE +")))
  assert_eq(s.receive(@irc.parse("903 n :success")), [])
  assert_eq(s.receive(@irc.parse("CAP * ACK other"))[0].params, ["END"])
}

///|
test "SASL unexpected challenge and capability revocation are terminal" {
  for line in ["AUTHENTICATE aGVsbG8=", "CAP n DEL sasl"] {
    let s = @irc.Session::new([], plain=Some(@irc.SaslPlain::new("u", "p")))
    ignore(s.start("n", "u", "r"))
    ignore(s.receive(@irc.parse("CAP * LS :sasl")))
    ignore(s.receive(@irc.parse("CAP * ACK sasl")))
    assert_true(
      try {
        ignore(s.receive(@irc.parse(line)))
        false
      } catch {
        _ => true
      },
    )
    assert_eq(s.status(), "failed")
  }
}
