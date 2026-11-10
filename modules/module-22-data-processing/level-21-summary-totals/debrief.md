# Ledger Rollup

## Why it works
This is the classic control-break report from the COBOL days: sort by the grouping
keys, then read the rows in order and compare each row's keys with the previous one.
When the team changes, the team that just ended is complete, so its subtotal is
printed and reset; when the department changes, the same happens one level up. The
team check comes first, because a new department always ends a team too. The last
group never meets a "next row", so `END` prints its totals and the grand total.
`sort -s` matters: without it, sort breaks ties on the whole line and the rows of a
team come out ordered by date and description text instead of ledger order.

Unlike `sum[$1] += $5` with a loop in `END` (one total per key, at the end), a
control break interleaves the subtotals with the data, which is what makes a
report readable.

## Common mistakes
- `-F,` alone: `"1,234.50"` becomes `"1` and `234.50"`, and the amount is 1.
- `(45.00) + 0` is 0 in awk: the parenthesised refund has to become `-45` first.
- Printing the department total before the team total when both change.
- Forgetting the totals of the last group in `END`.

## Learn next
gawk 5.3 reads quoted CSV fields directly with `gawk --csv`. In SQL the same report
is `GROUP BY ROLLUP(department, team)`; `datamash -s -t, -g 1,2 sum 5` gives the
per-group totals in one command (without the interleaving).
