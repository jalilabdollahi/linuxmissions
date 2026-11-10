# Bank Payroll File

## Why it works
Banks, mainframes and payment systems still exchange fixed-width files: every field
has a start column and a length, and there are no separators. `cut -c2-7,8-37,46-54`
cuts by character position, and `--output-delimiter='|'` writes a separator between
the ranges, which turns the record into something awk can split with `-F'|'`. The
name field is padded to 30 characters, so `sub(/ +$/, "", $2)` trims it. Amounts use
implied decimals (the bank never writes the point), so dividing by 100 and printing
with `%.2f` gives `123.45`, and the numeric conversion drops the zero padding.

A name like `Berg, Anna` contains the CSV delimiter. Without quotes the spreadsheet
would see four columns on that line and shift the amount into the wrong one.

## Common mistakes
- Using cut without `--output-delimiter`: adjacent ranges are glued together and the
  id runs straight into the name.
- `sed 's/ //g'` to "trim": it also removes the space between first and last name.
- Keeping the H and T records: they are bank control records, not payments. The
  trailer is still useful: its record count and total let you check your result
  (`awk -F, 'NR>1 {s+=$NF} END {print NR-1, s}' payroll.csv` sees the names'
  commas as separators, but $NF is still the amount).

## Learn next
`cut -c` counts bytes on most systems, so fixed-width files with UTF-8 names can
shift; gawk's `substr()` counts characters in a UTF-8 locale. GNU awk can also read
fixed-width data directly with `FIELDWIDTHS="1 6 30 8 9 3 22"`.
