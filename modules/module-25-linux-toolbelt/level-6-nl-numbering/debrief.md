# Line Numbers Like the Editor

## Why it works
`nl` numbers only non-empty lines by default (`-b t`). `-b a` numbers every
body line, so line 57 in `review.txt` is line 57 in the editor. `-w 3` sets the
width of the number column and `-s ': '` the text between number and line,
which together give the `%3d: line` layout. `cat -n` or `awk '{printf "%3d: %s\n", NR, $0}'`
would give the same result.

## Common mistakes
- Plain `nl nginx.conf`: the blank lines are skipped, so every comment after the
  first blank line points at the wrong place.
- Forgetting `-w`: the default width is 6, with a tab as separator.
- Counting lines that only contain spaces as blank: `-b t` numbers them, an
  editor does too, `nl -b a` always does.

## Learn next
`nl -b pREGEX` numbers only lines matching a pattern, and `nl -n rz` pads the
numbers with zeros (`-n ln` left-aligns them).
