# Expense Report

## Why it works
awk reads the file one line at a time and splits it on `-F,`. The condition
`NR > 1 && $3 != ""` keeps only real expense rows. `sum[$3] += $4` uses the
category text as an array key, so awk keeps one running total per category without
being told the category names. The `END` block runs once after the last line and prints
the totals. `for (c in sum)` returns the keys in no particular order, so `sort -k2,2nr`
puts them in order afterwards.

## Common mistakes
- `print sum[c]` instead of `printf "%.2f"`: awk's default output format (`OFMT`, `%.6g`)
  shows only 6 significant digits, so 19450.06 becomes 19450.1. That is wrong in a
  finance report.
- Summing every line: the TOTAL footer becomes an extra "category" with an empty name,
  and its value is as large as everything else combined.
- `sort -r` without `-n` sorts the numbers as text ("9" comes after "10").

## Next step
Real-world CSV can have quoted fields with commas inside (`"Smith, J"`). Plain `-F,`
breaks on those. GNU awk's `FPAT` or a CSV-aware tool (`csvkit`, `mlr`, `python -m csv`)
handles them. `awk ... | column -t` makes the report easier to read.
