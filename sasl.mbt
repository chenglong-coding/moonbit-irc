///|
/// Required SASL PLAIN credentials. No Debug representation exposes the secret.
/// Hosts must use a protected transport. Identities are passed as supplied; SASLprep is not implemented.
pub struct SaslPlain {
  payload : String
}

///|
pub fn SaslPlain::new(
  username : String,
  password : String,
  authorization_id? : String = "",
) -> SaslPlain raise IrcError {
  if username.is_empty() || password.is_empty() {
    raise Invalid("empty SASL identity or password")
  }
  for value in [username, password, authorization_id] {
    if value.length() > 4096 ||
      value.contains("\u0000") ||
      !valid_unicode(value) {
      raise Invalid("invalid SASL credential")
    }
  }
  {
    payload: @base64.encode(
      @utf8.encode(authorization_id + "\u0000" + username + "\u0000" + password),
    ),
  }
}

///|
fn auth_message(value : String) -> Message {
  { tags: [], prefix: None, command: "AUTHENTICATE", params: [value], }
}
