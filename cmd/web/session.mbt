///|
let sessions : Map[String, @lib.Session] = Map([])

///|
pub fn session_open(
  key : String,
  nick : String,
  user : String,
  realname : String,
  caps : String,
) -> String {
  try {
    if sessions.length() >= 64 || sessions.contains(key) {
      raise Failure("session handle limit or duplicate")
    }
    let session = @lib.Session::new(
      caps
      .split(" ")
      .filter(x => !x.is_empty())
      .map(x => x.to_owned())
      .collect(),
    )
    let lines = session
      .start(nick, user, realname)
      .map(m => m.encode())
      .join("")
    sessions[key] = session
    lines
  } catch {
    e => "ERROR: " + Repr(e).to_string()
  }
}

///|
pub fn session_receive(key : String, line : String) -> String {
  try {
    let session = match sessions.get(key) {
      Some(s) => s
      None => raise Failure("unknown session")
    }
    session.receive(@lib.parse(line)).map(m => m.encode()).join("")
  } catch {
    e => "ERROR: " + Repr(e).to_string()
  }
}

///|
pub fn session_status(key : String) -> String {
  match sessions.get(key) {
    Some(s) => s.status()
    None => "closed"
  }
}

///|
pub fn session_close(key : String) -> Unit {
  sessions.remove(key)
}

///|
pub fn validate_outgoing(line : String) -> String {
  @lib.parse(line).encode() catch {
    e => "ERROR: " + Repr(e).to_string()
  }
}
