# Fourteen Pieces

## Why it works
`split` (or a transfer tool) cuts a file into byte ranges, so `cat` with the
parts in the right order rebuilds it exactly. `backup.part{1..14}` is brace
expansion: the shell writes the fourteen names out in numeric order before
`cat` runs, and the stray `backup.part7 (copy)` simply isn't one of them.
`sha256sum -c` then proves the rebuilt file is byte-identical to the one the
sender hashed, before you trust it enough to unpack.

## Common mistakes
- `cat backup.part* > backup.tar.gz`: globs sort alphabetically
  (part1, part10, ..., part14, part2, ...) and also match the copy. The size can
  even look right while the content is scrambled; gzip then fails with
  "invalid compressed data" or "unexpected end of file".
- Extracting before checking the checksum: a broken archive may still unpack
  half its files and look fine.

## Learn next
`ls | sort -V` (version sort) orders numbered names naturally. When you create
parts yourself, `split -d -a 3` gives zero-padded numeric suffixes (`part.000`,
`part.001`, ...), so even a plain glob is in order.
