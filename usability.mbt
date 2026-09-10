///|
/// Construct the matching PONG without performing transport I/O.
pub fn Message::pong(self : Message) -> Message raise IrcError {
  if self.command != "PING" ||
    self.params.is_empty() ||
    self.params.length() > 2 {
    raise Invalid("PING with one or two parameters required")
  }
  { tags: [], prefix: None, command: "PONG", params: self.params.copy(), }
}
