# What Does The Agent Phone Home To

## Why it works
`strings` scans a file for runs of printable characters, which is how readable
text is found inside code. `-n 8` ignores short runs that random bytes produce
by accident. The licence ID was stored as UTF-16LE (two bytes per character,
every second byte zero), which the default 7-bit mode cannot see: `-e l`
reads 16-bit little-endian characters instead. Because the output is in file
order, a `sed` range from `TEST-BEGIN` to `TEST-END` removes the fixtures.

## Common mistakes
- `strings agent.bin | grep http` finds the decoys too and no licence at all.
- Reading `strings -e b` (big-endian) gives nothing sensible: UTF-16 comes in
  two byte orders and Windows and Linux builds use little-endian.

## Learn next
`strings -t d` prints the byte offset of every hit, handy with `xxd -s OFFSET`
(level 18) to look at the bytes around a string.
