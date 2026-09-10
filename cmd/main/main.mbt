///|
fn main raise {
  let m = @lib.parse(
    "@time=2026-09-10T00:00:00Z :alice!u@host PRIVMSG #moonbit :hello MoonBit",
  )
  println("command=\{m.command}, target=\{m.params[0]}, text=\{m.params[1]}")
  println(m.encode())
}
