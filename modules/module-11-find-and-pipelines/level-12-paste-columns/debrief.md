# Three Exports, One Report

## Why it works
`paste` reads its files in parallel and joins line N of each with a tab, which
is exactly how per-metric exports fit together. `-` stands for standard input,
so a cleaned-up copy of cpu.txt can go in the middle without a temp file. With
`-s` paste works the other way round: all lines of one input become a single
line, joined by the `-d` character, with no separator after the last item.

## Common mistakes
- Pasting cpu.txt as it is: each row becomes `host<TAB>71.6\r<TAB>29.9`.
  The terminal hides the `\r`, but scripts reading the file break on it.
- `tr '\n' ','` instead of `paste -s`: the last newline also becomes a comma,
  leaving `...,lb-06,` and no newline at the end.
- `paste -d,` without `-s` does nothing useful on a single column.

## Learn next
`paste - - - < file` folds a single column into rows of three, and
`paste -d'\t\n'` cycles through several separators. `dos2unix` converts a
file in place, and `file cpu.txt` tells you "with CRLF line terminators"
before you start.
