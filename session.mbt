///|
/// Registration and CAP negotiation for one connection. Socket and timeout ownership stays with the host.
pub struct Session {
  caps : Capabilities
  desired : Array[String]
  pending : Map[String, Bool]
  mut state : String
  mut requested : Bool
}

///|
pub fn Session::new(desired : Array[String]) -> Session raise IrcError {
  if desired.length() > 64 {
    raise Invalid("too many desired capabilities")
  }
  for name in desired {
    ignore(capability_token(name, false, false))
    if name == "sasl" {
      raise Invalid("SASL authentication not implemented")
    }
  }
  {
    caps: Capabilities::new(),
    desired: desired.copy(),
    pending: Map([]),
    state: "new",
    requested: false,
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
  let messages = [
    Message::{ tags: [], prefix: None, command: "CAP", params: ["LS", "302"], },
    Message::{ tags: [], prefix: None, command: "NICK", params: [nick], },
    Message::{
      tags: [],
      prefix: None,
      command: "USER",
      params: [user, "0", "*", realname],
    },
  ]
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
  }
  if message.command == "ERROR" ||
    ["432", "433", "436", "464", "465"].contains(message.command) {
    raise Invalid("server rejected session: " + message.command)
  }
  if message.command == "PING" {
    return [message.pong()]
  }
  if message.command == "001" {
    self.state = "registered"
    return []
  }
  // Legacy servers may reject CAP; NICK/USER were already sent.
  if self.state == "negotiating" &&
    message.command == "421" &&
    message.params.contains("CAP") {
    self.state = "registering"
    return []
  }
  if message.command != "CAP" {
    return []
  }
  self.caps.observe(message)
  let kind = message.params[1]
  let out = []
  if kind == "LS" && self.caps.listing_complete() && !self.requested {
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
  if self.state == "negotiating" && self.requested && self.pending.is_empty() {
    out.push(Message::{
      tags: [],
      prefix: None,
      command: "CAP",
      params: ["END"],
    })
    self.state = "registering"
  }
  out
}
