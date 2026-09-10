///|
test "parameter count and Unicode octet limit" {
  let params = Array::make(15, "x")
  assert_eq(@irc.parse("CMD " + params.join(" ")).params.length(), 15)
  params.push("x")
  assert_true(
    try {
      ignore(@irc.parse("CMD " + params.join(" ")))
      false
    } catch {
      _ => true
    },
  )
  let long = Array::make(170, "中").join("")
  assert_true(
    try {
      ignore(@irc.parse("PRIVMSG #x :" + long))
      false
    } catch {
      _ => true
    },
  )
  assert_eq(@irc.parse("CMD \tvalue").params, ["\tvalue"])
}

///|
test "serializer rejects command masquerading as prefix" {
  let m : @irc.Message = {
    tags: [],
    prefix: None,
    command: ":evil",
    params: ["PING"],
  }
  assert_true(
    try {
      ignore(m.encode())
      false
    } catch {
      _ => true
    },
  )
}
