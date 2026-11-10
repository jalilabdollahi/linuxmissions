# Newest Release First

## Why it works
`tac` reverses *records*, and a record is whatever lies between separators. By
default the separator is a newline, so it reverses lines. `-s '----'` makes the
separator the ---- marker, so each release is one record. By default the
separator is treated as the *end* of a record, which would move every ----
line to the wrong end of its block; `-b` attaches it to the start of the record
instead, matching how the file is written.

## Common mistakes
- Plain `tac CHANGES`: the order of lines inside each release is reversed too.
- `tac -s '----'` without `-b`: the blocks come out in order but each ----
  separator ends up after its block, shifting every header.
- A separator string that also occurs inside a line splits that line; check the
  data, or use `-r` with a regular expression.

## Learn next
`tac -r -s '^v[0-9]'` style regular-expression separators can split at a
version header instead, and awk can do the same job when the rule is more
complicated than "starts with".
