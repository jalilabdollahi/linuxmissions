# The Noisiest Services

## Why it works
`grep -c` prints one count per file, `logs/x.log:N`, and that count is the
number of matching *lines*, so an ERROR line that mentions ERROR twice is
counted once. `-w` requires ERROR to stand alone as a word, which rules out
`rcode=NOERROR` and `ERRORS_RESET=12`. awk then filters on the number and
`sort -k2,2nr` ranks numerically by the second column.

## Common mistakes
- `grep -c ERROR` counts `NOERROR` and `ERRORS_RESET` lines too, which pushes
  quiet services over the line; `grep -ci error` also counts "last error was
  transient" warnings.
- `grep -o ERROR | wc -l` counts occurrences, not lines.
- `sort -r` without `-n` sorts text, so 9 comes before 51. And "more than 50"
  leaves out the service with exactly 50.

## Learn next
To count by the level column exactly, ask awk: `awk '$2 == "ERROR" {n[FILENAME]++}
END {for (f in n) print f, n[f]}' logs/*.log`. `grep -c` prints `:0` for files
without any match, and `grep -L` lists those files.
