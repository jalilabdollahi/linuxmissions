# World Writable Files

## Why it works
`find -perm -o+w` (or `-perm -002`) matches files where *at least* the
"others write" bit is set, so it finds 666, 777, 646 and 662 alike. `chmod o-w`
is a *relative* change: it clears that one bit and keeps the rest, which matters
because `shared.csv` is group-writable and `run backup.sh` is a script on purpose.

## Common mistakes
- `chmod -R 644 app`: no more world-writable files, but scripts lose `x` and
  group-writable data stops being writable for the team. A security fix that
  breaks the app gets rolled back.
- `chmod go-w`: removes the group's write too, which nobody asked for.
- Looping with `for f in $(find ...)`: the name `run backup.sh` splits into two
  words. `-exec ... {} +` passes each name intact.

## Learn next
Directories can be world-writable too: `find / -xdev -type d -perm -0002 ! -perm -1000`
lists world-writable directories *without* the sticky bit, a classic audit item.
