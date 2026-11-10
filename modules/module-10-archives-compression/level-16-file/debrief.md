# What's in a Name

## Why it works
On Linux an extension is only part of the name; programs that care look at
the first bytes. `file` compares those against a database of magic numbers:
`1f 8b` is gzip, `BZh` is bzip2, `fd 37 7a 58 5a 00` is xz, `PK\003\004` is
zip, `%PDF` is PDF, and a tar archive has `ustar` at byte 257. `file -z` also
decompresses the start of a gzip stream, which is the only way to tell a
`.tar.gz` from a gzipped text file. Zero-byte files have no magic at all and
`file` calls them `empty`.

## Common mistakes
- Trusting `--mime-type` alone: it says `application/gzip` for both gz and
  tar.gz.
- Matching `*tar*` before `gzip*` in the case: patterns are tried in order,
  and `file -bz` output contains both words.
- `mv "$f" sorted/$t/` keeps the carver's wrong extension; you have to build
  the new name from the chunk number.

## Learn next
`xxd FILE | head -2` or `od -A x -t x1z FILE | head` show the magic bytes
yourself. `file -i` prints MIME type and charset, and `file -k` keeps going
after the first match, which reveals polyglot files that are valid in two
formats at once.
