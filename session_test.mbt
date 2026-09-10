///|
test "session registration waits for complete capabilities and acknowledgements" {
  let s = @irc.Session::new(["one", "two", "missing", "one"])
  assert_eq(s.start("nick", "user", "Real Name").length(), 3)
  assert_eq(s.receive(@irc.parse("CAP * LS * :one")), [])
  assert_eq(s.receive(@irc.parse("CAP * LS :two")).length(), 2)
  assert_eq(s.receive(@irc.parse("CAP * ACK one")), [])
  assert_eq(s.receive(@irc.parse("CAP * NAK two"))[0].params, ["END"])
  assert_eq(s.status(), "registering")
  ignore(s.receive(@irc.parse(":server 001 nick :Welcome")))
  assert_eq(s.status(), "registered")
  assert_true(s.enabled("one"))
  assert_false(s.enabled("two"))
}

///|
test "session ping legacy server and empty capabilities" {
  for caps in ["CAP * LS :", "CAP * LS :unknown"] {
    let s = @irc.Session::new([])
    ignore(s.start("n", "u", "r"))
    assert_eq(s.receive(@irc.parse(caps))[0].params, ["END"])
    assert_eq(
      s.receive(@irc.parse("PING :token"))[0].encode(),
      "PONG token\r\n",
    )
  }
  let s = @irc.Session::new([])
  ignore(s.start("n", "u", "r"))
  ignore(s.receive(@irc.parse(":server 421 n CAP :Unknown command")))
  ignore(s.receive(@irc.parse(":server 001 n :Welcome")))
  assert_eq(s.status(), "registered")
}

///|
test "session errors are terminal and registration rejects injection" {
  for code in ["432", "433", "436", "464", "465", "ERROR"] {
    let s = @irc.Session::new([])
    ignore(s.start("n", "u", "r"))
    assert_true(
      try {
        ignore(s.receive(@irc.parse(code + " n :rejected")))
        false
      } catch {
        _ => true
      },
    )
    assert_eq(s.status(), "failed")
  }
  let s = @irc.Session::new([])
  assert_true(
    try {
      ignore(s.start("n\r\nQUIT", "u", "r"))
      false
    } catch {
      _ => true
    },
  )
  assert_eq(s.status(), "new")
  assert_true(
    try {
      ignore(@irc.Session::new(["sasl"]))
      false
    } catch {
      _ => true
    },
  )
}

///|
test "session negotiates new capabilities after registration without END" {
  let s = @irc.Session::new(["later"])
  ignore(s.start("n", "u", "r"))
  ignore(s.receive(@irc.parse("CAP * LS :")))
  ignore(s.receive(@irc.parse("001 n :Welcome")))
  assert_eq(s.receive(@irc.parse("CAP n NEW later"))[0].params, ["REQ", "later"])
  assert_eq(s.receive(@irc.parse("CAP n ACK later")), [])
  assert_true(s.enabled("later"))
  ignore(s.receive(@irc.parse("CAP n DEL later")))
  assert_false(s.enabled("later"))
}
