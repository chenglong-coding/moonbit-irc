///|
pub struct Decoder {
  priv buffer : Array[Byte]
  priv mut failed : Bool
} derive(Debug)

///|
pub fn Decoder::new() -> Decoder {
  { buffer: [], failed: false, }
}

///|
pub fn Decoder::feed(
  self : Decoder,
  bytes : Bytes,
) -> Array[Message] raise IrcError {
  if self.failed {
    raise Invalid("decoder failed")
  }
  errdefer {
    self.failed = true
  }
  let out = []
  for b in bytes {
    if b == 10 {
      if self.buffer.is_empty() || self.buffer[self.buffer.length() - 1] != 13 {
        raise Invalid("expected CRLF")
      }
      ignore(self.buffer.pop())
      let line = @utf8.decode(Bytes::from_array(self.buffer)) catch {
        _ => raise Invalid("invalid UTF-8")
      }
      self.buffer.clear()
      out.push(parse(line))
    } else {
      self.buffer.push(b)
      if self.buffer.length() > 8192 {
        raise Invalid("line limit exceeded")
      }
    }
  }
  out
}

///|
pub fn Decoder::finish(self : Decoder) -> Unit raise IrcError {
  if self.failed || !self.buffer.is_empty() {
    raise Invalid("truncated or invalid stream")
  }
}
