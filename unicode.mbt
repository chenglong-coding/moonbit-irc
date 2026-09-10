///|
fn valid_unicode(text : String) -> Bool {
  let mut i = 0
  while i < text.length() {
    let u = text[i].to_int()
    if u >= 0xd800 && u <= 0xdbff {
      if i + 1 >= text.length() {
        return false
      }
      let next = text[i + 1].to_int()
      if next < 0xdc00 || next > 0xdfff {
        return false
      }
      i += 2
    } else {
      if u >= 0xdc00 && u <= 0xdfff {
        return false
      }
      i += 1
    }
  }
  true
}
