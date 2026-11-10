# Legacy Transfer

## Why it works
A file name is only a label. Tools like `file`, and strict receivers like this
transfer system, read the first bytes: gzip starts with `1f 8b`, bzip2 with
`BZh`, xz with `fd 37 7a 58 5a 00`. `tar -cjf` sends the tar stream through
bzip2, so the archive gets the right header. `bzip2 -k` keeps the original,
because bzip2, like gzip, normally replaces the file it compresses.

## Common mistakes
- `mv x.tar.gz x.tar.bz2` or `tar -czf x.tar.bz2`: GNU tar picks the compressor
  from the flag you give, not from the file name you write.
- `bzip2 audit.log` without `-k` deletes the log; `bunzip2 -k audit.log.bz2`
  brings it back.
- Forgetting `-f` order: `tar -cfj` takes `j` as the archive name.

## Learn next
`tar -caf NAME.tar.bz2 DIR` (`-a`, auto-compress) picks the compressor from
the suffix. `bzip2 -t` tests an archive without unpacking, and `xxd FILE | head
-1` shows the magic bytes yourself.
