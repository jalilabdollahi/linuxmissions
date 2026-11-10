# Pretty Table

## Why it works
`column -t` reads all lines first, works out the widest value in each column, and pads
every cell to that width, so each column starts at the same position on every line.
`-s ,` sets the input separator. Without it, column splits on whitespace and
"Public REST API" turns into three columns, which pushes everything after it out of line.

## Common mistakes
- Forgetting `-s ,`: the header (no spaces at all) stays one long cell and the
  descriptions are split into words.
- Tabs instead of spaces (`tr , '\t'`). They only line up while every value is shorter
  than the tab width and the viewer uses the same tab stops.
- `printf "%5s"` makes numbers right-aligned. That is often nicer for numbers, but
  it is a different layout from left-aligned columns.

## Next step
`column -t -s , -o ' | '` (util-linux) sets the output separator, and
`column -t -s , -N` / `--table-right port` name columns and right-align some of them.
On any system, `awk -F, '{ printf "%-10s %6s\n", $1, $4 }'` gives full control over
width and alignment.
