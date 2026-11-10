# Five Megabytes Max

## Why it works
`split -b 5000000` cuts the file into pieces of exactly that many bytes, and
the two-letter suffixes `aa, ab, ac ...` sort in the same order the pieces
were cut, so `cat db-backup.tar.gz.part-*` rebuilds the original. The checksum
was taken from the folder the backup lives in, so the line reads
`<hash>  db-backup.tar.gz` and `sha256sum -c` finds the rebuilt file in the
vendor's folder.

## Common mistakes
- `split -b 5M` makes 5 MiB pieces (5,242,880 bytes): the share rejects every
  one except the last. GNU split also accepts `5MB` for 5,000,000 bytes, and
  `5K`/`5KB` work the same way (1024 vs 1000).
- `sha256sum outgoing/../db-backup.tar.gz` or an absolute path: the vendor has
  no such path, so `-c` reports "No such file or directory".
- `split -l` (by lines) on a binary file: "lines" in compressed data have
  random lengths, so the pieces have random sizes. Use `-b` for binaries.

## Learn next
`split -n 5` cuts into five equal pieces regardless of size, and
`sha256sum outgoing/*part-*` lets the vendor find which piece broke in transit.
