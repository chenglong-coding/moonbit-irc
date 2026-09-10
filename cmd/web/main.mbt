///|
pub fn run(input : String) -> String {
  try {
    let message = @lib.parse(input)
    Repr(message).to_string() + "\n\nCanonical wire:\n" + message.encode()
  } catch {
    e => "ERROR: " + Repr(e).to_string()
  }
}

///|
fn main {

}
