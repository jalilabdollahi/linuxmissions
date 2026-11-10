# Scanner Dump

## Why it works
Each `-` given to `paste` means "read the next line from standard input", so
`paste - - - -` takes four lines at a time and writes them as one row joined by
tabs. That only works if the input is exactly the data lines, four per parcel, which
is why the `--` separators have to go first. `paste -s` (serial) does the opposite
direction: it joins all lines of one input into a single line, and `-d,` uses a
comma instead of a tab.

The CRLF batches are the trap. With `\r` still on the lines, `--\r` is not `--`,
so `grep -vx` keeps those separators and every row after them is shifted. And even
when the rows line up, a `\r` left in the middle of a row is invisible in the
terminal but breaks the import (the weight becomes `2.35\r`).

## Common mistakes
- `grep -v -- --` without `-x`: it also drops any line that merely contains `--`.
- `grep -vx --` without the extra `--`: grep reads the pattern as an option.
- `paste -sd,` on the whole TSV instead of on the first column.

## Learn next
When the blocks have a variable number of lines (`key: value` records separated by
blank lines, as in `ldapsearch` or `/proc/meminfo`-like output), `paste` can't count
them; use awk's paragraph mode, `awk -v RS= '{ $1 = $1; print }'`.
