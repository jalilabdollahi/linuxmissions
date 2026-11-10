# Drain Rack B

## Why it works
awk gives you the fields of a line, but the moment you assign to one (`$4 = 0`)
it re-joins all fields with the output separator, a single space. A hand-aligned
table then loses its alignment. Printing the row yourself with `printf` and
fixed-width formats (`%-12s`) reproduces the layout, and a pattern restricted to
real data rows (`NF == 5`, not starting with `#`, rack field exactly `B`) leaves
comments, blank lines and look-alikes such as `web-b1` or `cache-b` alone.

## Common mistakes
- `awk '$4=0'` style one-liners: all spacing collapses.
- Matching `/B/` anywhere in the line: the comments and `web-b1` contain a B.
- Writing `awk ... file > file`: the shell truncates the file before awk reads it.

## Next step
`awk 'BEGIN{OFS="\t"}'` sets the output separator when you *want* a rebuilt line, and
`column -t` re-aligns a table when exact bytes do not matter.
