# Time and Permission

## Why it works
`stat -c '%a %Y'` prints exactly what the manifest stores: the octal mode and
the mtime as epoch seconds. Without `-L`, stat describes the entry itself, so
the symlink reports its own (drifted) time. Reading MANIFEST with
`while read -r mode epoch path` gives the last variable the rest of the line,
which keeps `acme agent helper` and `Release Notes.txt` in one piece.
The fix uses `touch -h -d @EPOCH`, which sets the link's own time instead of
the target's, and skips `chmod` on the link.

## Common mistakes
- `chmod 777 lib/libacme.so.4` follows the link and makes the real library
  world-writable, a new drift (and a security hole).
- `touch -d @N` on the link without `-h` changes the library's mtime.
- `awk '{print $3}' MANIFEST` cuts paths at the first space.
- Fixing first and listing later: once fixed, there is nothing left to list.

## Learn next
`tar` stores modes and mtimes: `tar -xpf` restores modes exactly (default
for root), and `--preserve-permissions`/`--touch` control it. `find PATH
-newermt '2026-10-01'` filters by mtime, and on macOS the same stat call is
`stat -f '%Lp %m'`.
