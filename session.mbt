///|
/// Registration and CAP negotiation for one connection. Socket and timeout ownership stays with the host.
pub struct Session {
  caps : Capabilities
  desired : Array[String]
  pending : Map[String, Bool]
  mut state : String
  mut requested : Bool
  mut auth_data : String
  mut auth_state : String
}

///|
pub fn Session::new(
  desired : Array[String],
  plain? : SaslPlain? = None,
) -> Session raise IrcError {
  if desired.length() > 64 {
    raise Invalid("too many desired capabilities")
  }
  for name in desired {
    ignore(capability_token(name, false, false))
    if name == "sasl" && plain is None {
      raise Invalid("SASL credentials required")
    }
  }
  let wanted = desired.copy()
  if plain is Some(_) && !wanted.contains("sasl") {
    wanted.push("sasl")
  }
  {
    caps: Capabilities::new(),
    desired: wanted,
    pending: Map([]),
    state: "new",
    requested: false,
    auth_data: match plain {
      Some(p) => p.payload
      None => ""
    },
    auth_state: if plain is Some(_) {
      "required"
    } else {
      "none"
    },
  }
}

///|
pub fn Session::status(self : Session) -> String {
  self.state
}

///|
pub fn Session::enabled(self : Session, name : String) -> Bool {
  self.caps.enabled(name)
}

///|
pub fn Session::start(
  self : Session,
  nick : String,
  user : String,
  realname : String,
  server_password? : String? = None,
) -> Array[Message] raise IrcError {
  if self.state != "new" {
    raise Invalid("session already started")
  }
  for value in [nick, user] {
    if value.is_empty() ||
      value.has_prefix(":") ||
      value.to_array().iter().any(c => c.to_int() <= 32) {
      raise Invalid("invalid registration identifier")
    }
  }
  let messages = []
  if server_password is Some(password) {
    if password.is_empty() {
      raise Invalid("empty server password")
    }
    messages.push(Message::{
      tags: [],
      prefix: None,
      command: "PASS",
      params: [password],
    })
  }
  let registration = [
    Message::{ tags: [], prefix: None, command: "CAP", params: ["LS", "302"], },
    Message::{ tags: [], prefix: None, command: "NICK", params: [nick], },
    Message::{
      tags: [],
      prefix: None,
      command: "USER",
      params: [user, "0", "*", realname],
    },
  ]
  for message in registration {
    messages.push(message)
  }
  for message in messages {
    ignore(message.encode())
  }
  self.state = "negotiating"
  messages
}

///|
pub fn Session::receive(
  self : Session,
  message : Message,
) -> Array[Message] raise IrcError {
  if self.state == "new" || self.state == "failed" {
    raise Invalid("session is not receiving")
  }
  errdefer {
    self.state = "failed"
    self.auth_data = ""
  }
  if message.command == "ERROR" ||
    ["432", "433", "436", "464", "465"].contains(message.command) {
    raise Invalid("server rejected session: " + message.command)
  }
  if message.command == "PING" {
    return [message.pong()]
  }
  if ["902", "904", "905", "906", "907"].contains(message.command) &&
    self.auth_state != "none" {
    raise Invalid("SASL authentication rejected: " + message.command)
  }
  if message.command == "AUTHENTICATE" {
    if self.auth_state != "challenge" || message.params != ["+"] {
      raise Invalid("unexpected SASL challenge")
    }
    let out = []
    let mut at = 0
    while at < self.auth_data.length() {
      let end = (at + 400).min(self.auth_data.length())
      out.push(auth_message(self.auth_data[at:end].to_owned()))
      at = end
    }
    if self.auth_data.length() % 400 == 0 {
      out.push(auth_message("+"))
    }
    self.auth_data = ""
    self.auth_state = "result"
    return out
  }
  if message.command == "903" {
    if self.auth_state != "result" {
      raise Invalid("unexpected SASL success")
    }
    self.auth_state = "success"
    return self.finish_negotiation()
  }
  if message.command == "001" {
    if self.auth_state != "none" && self.auth_state != "success" {
      raise Invalid("registration before required authentication")
    }

    self.state = "registered"
    return []
  }
  // Legacy servers may reject CAP; NICK/USER were already sent.
  if self.state == "negotiating" &&
    message.command == "421" &&
    message.params.contains("CAP") {
    if self.auth_state != "none" {
      raise Invalid("server does not support required SASL")
    }
    self.state = "registering"
    return []
  }
  if message.command != "CAP" {
    return []
  }
  self.caps.observe(message)
  let kind = message.params[1]
  if (self.auth_state == "challenge" || self.auth_state == "result") &&
    !self.caps.enabled("sasl") {
    raise Invalid("SASL capability revoked during authentication")
  }
  let out = []
  if kind == "LS" && self.caps.listing_complete() && !self.requested {
    if self.auth_state == "required" {
      if !self.caps.available("sasl") {
        raise Invalid("SASL unavailable")
      }
      if self.caps.value("sasl") is Some(mechanisms) {
        if !mechanisms.split(",").any(x => x == "PLAIN") {
          raise Invalid("SASL PLAIN unavailable")
        }
      }
    }
    self.requested = true
    for name in self.desired {
      if self.caps.available(name) && !self.pending.contains(name) {
        out.push(self.caps.request([name]))
        self.pending[name] = true
      }
    }
  }
  if kind == "ACK" || kind == "NAK" || kind == "DEL" {
    let tokens = message.params[message.params.length() - 1].split(" ")
    for token in tokens {
      let name = if token.has_prefix("-") {
        token[1:].to_owned()
      } else {
        token.to_owned()
      }
      if kind != "ACK" || self.caps.enabled(name) {
        self.pending.remove(name)
      }
    }
    // A final ACK may commit capabilities from earlier continuation lines.
    for name in self.desired {
      if self.caps.enabled(name) {
        self.pending.remove(name)
      }
    }
  }
  if kind == "NEW" && self.state == "registered" {
    for name in self.desired {
      if self.caps.available(name) &&
        !self.caps.enabled(name) &&
        !self.pending.contains(name) {
        out.push(self.caps.request([name]))
        self.pending[name] = true
      }
    }
  }
  if self.auth_state == "required" &&
    self.requested &&
    !self.pending.contains("sasl") {
    if !self.caps.enabled("sasl") {
      raise Invalid("required SASL capability rejected")
    }
    self.auth_state = "challenge"
    out.push(auth_message("PLAIN"))
  }
  for message in self.finish_negotiation() {
    out.push(message)
  }
  out
}

///|
fn Session::finish_negotiation(self : Session) -> Array[Message] {
  if self.state == "negotiating" &&
    self.requested &&
    self.pending.is_empty() &&
    (self.auth_state == "none" || self.auth_state == "success") {
    self.state = "registering"
    [Message::{ tags: [], prefix: None, command: "CAP", params: ["END"], }]
  } else {
    []
  }
}
