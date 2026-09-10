///|
/// Transport-independent IRCv3 CAP 302 state. Call observe for server CAP replies.
/// The caller owns authentication, registration timing and socket I/O.
pub struct Capabilities {
  mut offered : Map[String, String?]
  mut active : Map[String, Bool]
  staged : Map[String, Array[String]]
  mut ready : Bool
}

///|
pub fn Capabilities::new() -> Capabilities {
  { offered: Map([]), active: Map([]), staged: Map([]), ready: false, }
}

///|
pub fn Capabilities::available(self : Capabilities, name : String) -> Bool {
  self.offered.contains(name)
}

///|
pub fn Capabilities::value(self : Capabilities, name : String) -> String? {
  match self.offered.get(name) {
    Some(value) => value
    None => None
  }
}

///|
pub fn Capabilities::enabled(self : Capabilities, name : String) -> Bool {
  self.active.contains(name)
}

///|
pub fn Capabilities::listing_complete(self : Capabilities) -> Bool {
  self.ready
}

///|
fn capability_token(
  token : String,
  values : Bool,
  disabling : Bool,
) -> (String, String?, Bool) raise IrcError {
  let negative = token.has_prefix("-")
  let token = if negative && disabling { token[1:].to_owned() } else { token }
  let parts = token.split("=").map(x => x.to_owned()).collect()
  let name = parts[0]
  if name.is_empty() ||
    name.has_prefix("-") ||
    name
    .to_array()
    .iter()
    .any(c => c.to_int() <= 32 || c.to_int() >= 127 || c == ':' || c == '*') {
    raise Invalid("invalid capability name")
  }
  if parts.length() > 1 && !values {
    raise Invalid("capability values not allowed here")
  }
  (
    name,
    if parts.length() > 1 {
      Some(parts[1:].to_owned().join("="))
    } else {
      None
    },
    negative,
  )
}

///|
/// Build a bounded REQ. Does not enable capabilities before server ACK.
pub fn Capabilities::request(
  self : Capabilities,
  names : Array[String],
) -> Message raise IrcError {
  if names.is_empty() {
    raise Invalid("empty capability request")
  }
  for token in names {
    let (name, _, negative) = capability_token(token, false, true)
    if !negative &&
      !self.available(name) &&
      !(name == "cap-notify" && self.ready) {
      raise Invalid("capability not advertised")
    }
    if negative && name == "cap-notify" {
      raise Invalid("CAP 302 requires cap-notify")
    }
  }
  let msg = Message::{
    tags: [],
    prefix: None,
    command: "CAP",
    params: ["REQ", names.join(" ")],
  }
  ignore(msg.encode())
  msg
}

///|
/// Multiline LS/LIST/ACK commits atomically. Malformed replies leave state unchanged.
/// LS values are opaque and case-sensitive; duplicate names use the last value.
pub fn Capabilities::observe(
  self : Capabilities,
  message : Message,
) -> Unit raise IrcError {
  if message.command != "CAP" {
    return
  }
  let p = message.params
  if p.length() < 3 || p.length() > 4 {
    raise Invalid("invalid CAP reply")
  }
  let kind = p[1]
  if !["LS", "LIST", "ACK", "NAK", "NEW", "DEL"].contains(kind) {
    raise Invalid("unsupported CAP reply")
  }
  let continued = p.length() == 4
  if continued && (p[2] != "*" || !["LS", "LIST", "ACK"].contains(kind)) {
    raise Invalid("invalid CAP continuation")
  }
  let tokens = p[p.length() - 1]
    .split(" ")
    .filter(x => !x.is_empty())
    .map(x => x.to_owned())
    .collect()
  let combined = match self.staged.get(kind) {
    Some(tokens) => tokens.copy()
    None => []
  }
  for token in tokens {
    ignore(
      capability_token(
        token,
        kind == "LS" || kind == "NEW",
        kind == "ACK" || kind == "NAK",
      ),
    )
    combined.push(token)
  }
  if combined.length() > 512 || combined.join(" ").length() > 32768 {
    raise Invalid("CAP list limit")
  }
  if continued {
    self.staged[kind] = combined
    return
  }
  let offered = self.offered.copy()
  let active = self.active.copy()
  if kind == "LS" {
    offered.clear()
  }
  if kind == "LIST" {
    active.clear()
  }
  for token in combined {
    let (name, value, negative) = capability_token(
      token,
      kind == "LS" || kind == "NEW",
      kind == "ACK" || kind == "NAK",
    )
    match kind {
      "LS" | "NEW" => offered[name] = value
      "LIST" => active[name] = true
      "ACK" => if negative { active.remove(name) } else { active[name] = true }
      "DEL" => {
        offered.remove(name)
        active.remove(name)
      }
      _ => ()
    }
  }
  if offered.length() > 512 || active.length() > 512 {
    raise Invalid("CAP state limit")
  }
  // CAP 302 implicitly enables cap-notify after the server accepts LS.
  if kind == "LS" || kind == "LIST" {
    active["cap-notify"] = true
  }
  self.offered = offered
  self.active = active
  self.staged.remove(kind)
  if kind == "LS" {
    self.ready = true
  }
}
