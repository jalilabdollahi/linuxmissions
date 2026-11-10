# Unpack The Support Bundle

## Why it works
A MIME message is plain text: headers, then parts separated by the boundary
string the `Content-Type` header declares. `csplit` cuts on that line, `sed`
removes each part's own headers, and `base64 -d` decodes the body. After that,
what a part really is must come from its content: `file` (or the magic bytes in
`xxd`) shows that the "text" attachment is gzip data, so `zcat` reads it. The
log is UTF-16 with a byte order mark, which looks like binary to `grep` until
`iconv -f UTF-16 -t UTF-8` converts it, and only then does `grep -c` count
the ERROR lines.

## Common mistakes
- Trusting `Content-Type: text/plain` for the dmesg attachment.
- Running `grep -c ERROR` on the raw UTF-16 bytes: every character is
  followed by a zero byte, so it never matches.
- Reading the kernel version from the mail text (a guess) instead of the log,
  or taking the old setting instead of the recommended one.

## Learn next
`munpack` or Python's `email` module unpack MIME properly when you do this
often; `file -i` also prints the MIME type and charset of a file.
