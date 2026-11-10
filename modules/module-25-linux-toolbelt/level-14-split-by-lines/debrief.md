# Five Thousand At A Time

## Why it works
`split -l 5000` counts lines, and the header is just another line to it. So
the data is split on its own (`tail -n +2` removes the header first) and
`--filter` runs a small command for every piece before it is written: print the
saved header, then the piece. `$FILE` is the name `split` would have used, so
the result lands in `chunks/part-00.csv`, `part-01.csv`, and so on, each
with the header and at most 5000 rows.

## Common mistakes
- `split -l 5000 customers.csv` puts the header in the first piece only, which
  then holds 4,999 data rows; the other pieces have no header at all.
- `split -l 5000` on the data and a separate `cat header chunk` loop works too,
  but forget to remove the first lines and the header ends up repeated inside a
  chunk.
- Forgetting `-d` gives `part-aa.csv` instead of `part-00.csv`.

## Learn next
`split -n l/5 FILE` makes 5 pieces without cutting a line in half, and
`split -b` cuts by size (the archive trick from module 10).
