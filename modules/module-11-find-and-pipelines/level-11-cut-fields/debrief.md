# Columns for Two Audiences

## Why it works
`cut -f` selects fields, with the tab as default separator, so values with
spaces stay whole and empty notes fields keep their place. Ranges like
`1-10,12-` express "everything but column 11". For a different column order you
need a tool that prints fields where you tell it: `awk -F'\t' -v OFS='\t'`
splits on tabs only and puts a tab between the fields it prints.

## Common mistakes
- `cut -f5,2,9` prints hostname, serial, rack: cut always keeps the file's order.
- `awk '{print $5, $2, $9}'` without `-F'\t'` splits on every space, so
  `PowerEdge R650` becomes two fields and every column after it shifts. Without
  `OFS` the output fields are joined with spaces, not tabs.
- `cut -d' '` on a TSV: same problem as above.

## Learn next
`cut --complement -f11` (GNU) and `cut -f11 --output-delimiter=,` save typing.
`column -t -s$'\t' inventory.tsv` shows a TSV as an aligned table, and for
CSV with quoted commas inside values switch to a CSV-aware tool such as
`mlr --icsv --otsv cut -o -f serial,hostname,rack`.
