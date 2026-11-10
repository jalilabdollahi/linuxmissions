# Size Before You Unpack

## Why it works
An xz file ends with an index that records the compressed and uncompressed
size of every block, so `xz -l` can answer without decompressing. Its normal
output is for humans (`1,234.5 KiB`); `--robot` prints the same data as
tab-separated fields with exact byte counts, and the `totals` line already adds
up all files. `unxz -k` restores one file and keeps the `.xz`.

## Common mistakes
- Copying the rounded figure from `xz -l` or multiplying "4.2 MiB" by 1,048,576:
  that is off by thousands of bytes.
- `unxz exports/*.xz` to measure with `ls -l`: it fills the volume you were
  asked to plan for and deletes the `.xz` files.
- `gzip -l` reports the size modulo 4 GiB, so for large gzip files the "exact"
  number is wrong; xz has no such limit.

## Learn next
`xz -dc FILE.xz | wc -c` gives the exact size for any compressor, at the cost
of reading everything. `numfmt --to=iec 4404019` turns bytes back into a
human-readable size, and `xz -l -vv` shows the block and filter details.
