# YAML Forbids Tabs

## Why it works
A tab does not mean "two spaces": it moves to the next tab stop. `expand -t 2`
sets stops every 2 columns, so a tab at column 0 becomes 2 spaces, a space
followed by a tab becomes 2 spaces as well (the tab only has to reach column
2), and a tab after two spaces becomes 2 more. `-i` limits the conversion to
the leading whitespace of each line, so the tabs inside `banner` and `message`
are left alone. The output goes to a new file and is moved over the original
because `> deploy.yaml` would truncate the file before `expand` reads it.

## Common mistakes
- `sed 's/\t/  /g'`: every tab becomes two spaces, which breaks the mixed
  lines (space + tab ends up with 3 spaces) and also changes the quoted values.
- `expand -t 2` without `-i`: the meaningful tabs inside the values go too.
- `expand ... > deploy.yaml`: the file is empty afterwards.

## Learn next
`unexpand` goes the other way (next level), and `grep -nP '\t' file` lists the
lines that contain a tab, with `cat -A` or `grep -c` to check the result.
