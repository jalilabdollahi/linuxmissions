# Read It, Never Run It

## Why it works
The blob was wrapped in three layers. The outer one is base64url: it uses `-`
and `_` instead of `+` and `/` and has no `=` padding, so plain `base64 -d`
refuses it. `tr '_-' '/+'` restores the alphabet and a loop adds padding until
the length is a multiple of 4. The result is gzip data, and `gunzip` produces
text that is base64 again; one more `base64 -d` shows the payload. Each step
writes to a file or a pipe you can inspect: nothing is ever passed to `sh`.

## Common mistakes
- Running `echo BLOB | base64 -d | sh` "to see what happens". Decode, read,
  then decide; the attacker's command should only ever run on the attacker's
  schedule.
- Forgetting that `base64 -d` on a url-safe string reports "invalid input"
  and may print half of a result.
- Treating the first decoded bytes as text: `file -` or `xxd | head` shows the
  gzip magic number `1f 8b` first.

## Learn next
`basenc --base64url -d` decodes the URL-safe form directly (padding still
required), and `base64 -d -i` ignores garbage characters.
