# Vendor Ticket

## Why it works
`sed -n` turns off automatic printing, so only lines hit by `p` come out. An
address range `A,B` switches on at the first line matching A and off after
the next line matching B, and that end line is printed too: here the end is
the next header, which `sed '$d'` deletes again. The start pattern had to be
exact: `^\[database\]$` matches only the header itself, not
`[database-replica]` and not the comment that mentions `[database]`. For the
trace, `1200,1260p` prints by line number and `1260q` stops sed instead of
reading 40,000 lines for nothing.

## Common mistakes
- `/[database]/` unescaped is a bracket expression: "one of d, a, t, b, s,
  e", so it matches nearly every line.
- `/^\[database/` also starts at `[database-replica]`. That range ends at the
  next header, which is `[database]` itself, so the section you wanted is
  never printed.
- `head -1260 | tail -60` gives 60 lines: from 1200 to 1260 is 61 lines.

## Learn next
GNU sed can exclude the end line in one command:
`sed -n '/^\[database\]$/,/^\[/{/^\[/!p}'` prints only the non-header lines of
the range, so you would add the header back with `1i` or print it separately.
`awk 'NR>=1200 && NR<=1260'` and `awk '/^\[/{on = ($0 == "[database]")} on'`
are the awk versions; the second prints a section even when it is the last one in
the file.
