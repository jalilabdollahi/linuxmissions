# Weekly Cost Mail

## Why it works
`printf` formats are a small layout language: `%-20s` pads a string on the right to
20 columns (left-aligned), `%12.2f` rounds a number to 2 decimals and pads it on the
left to 12 columns (right-aligned), so the decimal points line up. Because every line
uses the same widths, the columns stay straight in any fixed-width font. awk's
`$2 + 0` turns the text into a number, which handles padding and exponent notation
(`1e3` is 1000), and `BEGIN`/`END` put the header and the total around the rows.

## Common mistakes
- `%-20.20s`: the precision cuts long names silently, without the `~` that tells the
  reader the name was cut.
- Not trimming the names: a leading space shifts that line's name one column right.
- `print name, cost` with tabs: tabs expand to different widths in different mail
  clients, which is how last week's columns got mixed up.
- `printf "%12s", $2`: prints the raw text (`1e3`, ` 980.5`) instead of the number.

## Learn next
`column -t -s, -R 2` (util-linux) right-aligns chosen columns for quick looks; for
thousands separators in a report, GNU printf supports `%'12.2f` in a locale that
defines them (`LC_NUMERIC=en_US.UTF-8`).
