# ETL Audit

## Why it works
A reconciliation compares *keys*, not counts. Both files are first reduced to the same
shape, `id cents`, with the ids in the same case and sorted the same way. After that
each question is one classic tool: `comm -23` gives ids only in the source (never
loaded), `uniq -d` gives ids that repeat in the load, `join` puts both amounts of an
invoice on one line so awk can compare them, and two sums give the totals. Here the
missing and the duplicated rows cancel out in the row count, which is exactly why the
job's "row count matches" check was useless.

## Common mistakes
- `int($3 * 100)`: binary floating point can't store 1.15 exactly, so
  `1.15 * 100` is 114.99999999999999 and `int()` makes it 114; dozens of invoices
  look "changed". Round with `%.0f`, or compare in units with two decimals.
- `-F,` with `$3`: `"Acme, Inc."` is split in two, so `$3` is ` Inc."` for those
  rows. The amount is always the last field, `$NF`.
- Joining without `sort -u` on the load side: each duplicated invoice is reported
  twice under [changed] if its amount differs, or the join output doubles up.
- Lowercasing in one file and not the other: every id looks missing.

## Learn next
`join -v1` prints the unpairable lines of file 1 (another way to get the missing ids),
and `join -a1 -a2 -e MISSING -o 0,1.2,2.2` does a full outer join, which shows every
difference in one table. Real pipelines put these checks into the ETL itself: compare
counts *and* sums *and* key sets after every load.
