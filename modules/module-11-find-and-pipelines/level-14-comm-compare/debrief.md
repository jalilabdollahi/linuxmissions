# Twin Servers Drift

## Why it works
`comm` reads two sorted files in step and sorts every line into one of three
columns: only in the first, only in the second, in both. `-23` and `-13`
hide the columns you don't want. Before that, each dump was reduced to the
thing being compared: `cut -f1` drops the version (different versions are not
drift), `sed 's/:.*//'` turns `libc6:amd64` and `libc6:i386` into `libc6`, and
`sort -u` sorts and removes the duplicates that creates.

## Common mistakes
- Comparing whole lines: every version difference then looks like a package
  that exists on one host only.
- `cut -d: -f1` on whole lines: versions can have an epoch (`1:9.6p1`), so
  the line `nginx<TAB>1:1.24.0` becomes `nginx<TAB>1`. Cut the tab field first.
- Unsorted input or input sorted under another locale: comm silently gives
  wrong columns (GNU comm warns "not in sorted order"). If two shells may
  differ, sort and compare with the same `LC_ALL=C`.

## Learn next
`comm -12` shows what both hosts have, and `diff <(...) <(...)` with process
substitution compares without temporary files. To find version drift, join
the dumps on the name instead: `join -t$'\t' web1.sorted web2.sorted | awk -F'\t' '$2 != $3'`.
