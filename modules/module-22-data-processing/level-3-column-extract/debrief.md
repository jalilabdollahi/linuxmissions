# The Column Moved

## Why it works
`tr , '\n'` turns the header into a list with one column name per line, so
`grep -n` reports each name's line number, which is its column number. `-x`
makes grep match the whole line, which is why `email_verified` (column 2 of
the new file) was not reported. With the numbers known, `tail -n +2` drops the
header and `cut -d, -f` picks the column.

## Common mistakes
- `grep -n email` without `-x`: it also finds `email_verified`, and taking the
  first hit fills the list with true/false.
- Reusing column 3 for both files because "it worked on the first one".
- `cut -f5` without `-d,`: cut splits on tabs by default and prints whole lines.

## Learn next
awk can look the column up by name, so a later reorder does not break your
script: `awk -F, 'NR==1 { for (i=1; i<=NF; i++) if ($i=="email") c=i; next } { print $c }' new_export.csv`.
Real CSV fields can contain quoted commas; `cut` does not understand quotes,
python's `csv` module and `mlr` do.
