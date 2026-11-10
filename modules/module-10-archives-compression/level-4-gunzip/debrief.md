# Partner Drop

## Why it works
`gunzip -c` (the same as `zcat`) writes the uncompressed bytes to standard
output and leaves the `.gz` alone, so the redirect decides where each CSV goes.
The loop runs once per file, and `basename "$f" .gz` turns
`inbox/orders-2026-11-09.csv.gz` into `orders-2026-11-09.csv`. The quotes keep
names with spaces in one piece.

## Common mistakes
- `gunzip inbox/*.gz` deletes every `.gz` and leaves the CSVs in `inbox/`.
- `gunzip -c inbox/*.gz > import/all.csv` concatenates all exports into one
  file, five header lines included. gzip streams can be joined like that,
  which is why it "works" without an error.
- `gunzip -k` on a file that already has its plain twin asks before
  overwriting it; in a script, add `-f` only when you mean it.

## Learn next
`gzip -l` shows the uncompressed size before you unpack, `zcat FILE.gz | head`
peeks at the header row, and `gzip -t` tests a file without writing anything.
