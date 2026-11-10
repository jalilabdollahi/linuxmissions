# Column Harvest

## Why it works
`awk -F,` splits every line on commas, so `$5` is the status and `$1`, `$3` are
username and email. `$5 == "active"` compares the whole field, which is why
`inactive`, `suspended` and the header row (`status`) were skipped. Printing
`$1 "," $3` rebuilds a two-column CSV.

## Common mistakes
- `grep active users.csv` also matches `inactive`. Compare the field, or anchor
  the text: `grep ',active$'`.
- `awk -F, '{print $1,$3}'` prints a space between fields (awk's default output
  separator), not a comma. Use `"," ` or `-v OFS=,`.
- `cut` can only select columns, it cannot filter rows or reorder fields
  (`cut -f3,1` still prints field 1 first).

## Learn next
`awk -F, 'NR > 1'` skips a header line, `awk -F, -v OFS=, '{print $3, $1}'`
swaps columns, and `column -s, -t users.csv` shows a CSV as an aligned table.
Real CSV files can have commas inside quotes; for those, use a CSV-aware tool
such as `mlr` or Python's csv module.
