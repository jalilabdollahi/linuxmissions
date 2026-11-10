# NAS Storage Bill

## Why it works
With `-F'\t'` awk splits only on tabs, so "Photos 2023/IMG_1.jpg" stays one
field and the user is always `$2`. `NF == 4` drops the find errors, which
have no tabs. Two arrays indexed by user name keep the running totals; awk
numbers are 64-bit floating point, so sums of many 50 GiB files are exact far
beyond 2^31 (the limit of a 32-bit integer). ISO dates (`YYYY-MM-DD`) sort the
same as text and as time, so `$4 < "2025-01-01"` is a correct date test.
`END` prints one line per user, and `sort -k2,2nr` ranks them.

## Common mistakes
- Default whitespace splitting: a space in the path shifts every field, and
  path fragments show up as "users".
- `/ 1e9` or `/ 1000^3`: that is GB, not GiB; the totals come out about 7%
  too high.
- Dates in other formats (`15/07/2024`, `Jul 15 2024`) do not compare
  correctly as strings; convert them to ISO first.

## Learn next
`du -sb /nas/home/*` gives totals per directory, but not per owner or age;
that is why reports like this start from `find -printf` (GNU find; on macOS
use `gfind` or `stat -f`). `numfmt --to=iec` (GNU coreutils) turns byte counts
into human units like `1.7T`, and `find /nas -user amira -mtime +365 -size +1G`
lists the old big files to clean up first.
