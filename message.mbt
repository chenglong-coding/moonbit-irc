///|
pub suberror IrcError {
  Invalid(String)
} derive(Debug)

///|
pub(all) struct Tag {
  key : String
  value : String?
} derive(Debug, Eq)

///|
pub(all) struct Message {
  tags : Array[Tag]
  prefix : String?
  command : String
  params : Array[String]
} derive(Debug, Eq)

///|
fn unescape(s : String) -> String {
  let mut out = ""
  let mut escaped = false
  for c in s.iter() {
    if escaped {
      out += match c {
        ':' => ";"
        's' => " "
        'r' => "\r"
        'n' => "\n"
        _ => c.to_string()
      }
      escaped = false
    } else if c == '\\' {
      escaped = true
    } else {
      out += c.to_string()
    }
  }
  out
}

///|
fn escape(s : String) -> String {
  let mut out = ""
  for c in s.iter() {
    out += match c {
      ';' => "\\:"
      ' ' => "\\s"
      '\\' => "\\\\"
      '\r' => "\\r"
      '\n' => "\\n"
      _ => c.to_string()
    }
  }
  out
}

///|
fn key_valid(s : String) -> Bool {
  if s == "" || s == "+" {
    return false
  }
  for c in s.iter() {
    if !(c >= 'a' && c <= 'z') &&
      !(c >= 'A' && c <= 'Z') &&
      !(c >= '0' && c <= '9') &&
      c != '-' &&
      c != '.' &&
      c != '/' &&
      c != '+' {
      return false
    }
  }
  true
}

///|
pub fn parse(line : String) -> Message raise IrcError {
  let text = if line.has_suffix("\r\n") {
    line[:line.length() - 2].to_owned()
  } else {
    line
  }
  if text.contains("\r") || text.contains("\n") || text.contains("\u0000") {
    raise Invalid("forbidden line character")
  }
  let mut rest = text
  let tags : Array[Tag] = []
  if rest.has_prefix("@") {
    let end = match rest.find(" ") {
      Some(v) => v
      None => raise Invalid("tags without command")
    }
    if @utf8.encode(rest[:end]).length() > 4094 {
      raise Invalid("tag section too long")
    }
    for entry in rest[1:end].split(";") {
      let raw = entry.to_owned()
      let (key, value) = match raw.find("=") {
        Some(p) => (raw[:p].to_owned(), Some(unescape(raw[p + 1:].to_owned())))
        None => (raw, None)
      }
      if !key_valid(key) {
        raise Invalid("invalid tag key")
      }
      let tag : Tag = { key, value, }
      let mut replaced = false
      for i in 0..<tags.length() {
        if tags[i].key == key {
          tags[i] = tag
          replaced = true
        }
      }
      if !replaced {
        tags.push(tag)
      }
    }
    rest = rest[end + 1:].to_owned()
  }
  if @utf8.encode(rest).length() > 510 {
    raise Invalid("IRC base message exceeds 512 bytes including CRLF")
  }
  let mut prefix = None
  if rest.has_prefix(":") {
    let end = match rest.find(" ") {
      Some(v) => v
      None => raise Invalid("prefix without command")
    }
    if end == 1 {
      raise Invalid("empty prefix")
    }
    prefix = Some(rest[1:end].to_owned())
    rest = rest[end + 1:].to_owned()
  }
  rest = rest.trim_start(chars=" ").to_owned()
  let end = rest.find(" ").unwrap_or(rest.length())
  let command = rest[:end].to_owned()
  if command == "" {
    raise Invalid("empty command")
  }
  let mut letters = true
  let mut numbers = command.length() == 3
  for c in command.iter() {
    if !(c >= 'a' && c <= 'z') && !(c >= 'A' && c <= 'Z') {
      letters = false
    }
    if c < '0' || c > '9' {
      numbers = false
    }
  }
  if !letters && !numbers {
    raise Invalid("invalid command")
  }
  rest = rest[end:].trim_start(chars=" ").to_owned()
  let params = []
  while rest != "" {
    if params.length() == 15 {
      raise Invalid("more than 15 parameters")
    }
    if rest.has_prefix(":") {
      params.push(rest[1:].to_owned())
      break
    }
    let end = rest.find(" ").unwrap_or(rest.length())
    params.push(rest[:end].to_owned())
    rest = rest[end:].trim_start(chars=" ").to_owned()
  }
  { tags, prefix, command: command.to_upper(), params, }
}

///|
pub fn Message::encode(self : Message) -> String raise IrcError {
  let mut out = ""
  if !self.tags.is_empty() {
    let parts = []
    for tag in self.tags {
      if !key_valid(tag.key) {
        raise Invalid("invalid tag key")
      }
      parts.push(
        tag.key +
        (match tag.value {
          Some(v) => "=" + escape(v)
          None => ""
        }),
      )
    }
    out += "@" + parts.join(";") + " "
  }
  if self.prefix is Some(prefix) {
    if prefix == "" || prefix.contains(" ") {
      raise Invalid("invalid prefix")
    }
    out += ":" + prefix + " "
  }
  if self.command == "" || self.command.contains(" ") {
    raise Invalid("invalid command")
  }
  out += self.command
  for i in 0..<self.params.length() {
    let p = self.params[i]
    let trailing = p == "" || p.contains(" ") || p.has_prefix(":")
    if trailing && i != self.params.length() - 1 {
      raise Invalid("nonfinal trailing parameter")
    }
    out += " " + (if trailing { ":" } else { "" }) + p
  }
  let decoded = parse(out)
  if decoded.command != self.command.to_upper() ||
    decoded.prefix != self.prefix ||
    decoded.params != self.params {
    raise Invalid("ambiguous message fields")
  }
  out + "\r\n"
}
