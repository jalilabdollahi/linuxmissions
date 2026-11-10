# Customer Totals

## Why it works
`join` is a merge: it walks both files once, top to bottom, and pairs lines whose key
fields are equal. It never searches, so both inputs must be sorted on the key in the
same order that join itself uses to compare: as text, by the current locale's
collation. Aggregating the orders first gives one summary line per customer, so the
join is one-to-one. `-a1` keeps customers without a partner, and `-e NONE` with `-o`
fills their missing fields, which sed then turns into `0,0.00`. Only at the end is the
report sorted the way humans want it, by id as a number.

## Common mistakes
- Sorting the ids with `sort -n` before join: `9` comes before `10` numerically, but
  join expects `10` before `9` (text order). GNU join warns "not in sorted order" and
  quietly skips partners; BSD join says nothing.
- Different locales for sort and join (one in a script with `LC_ALL=C`, the other in
  your `en_US.UTF-8` shell): the orders differ for punctuation and case, with the
  same silent losses. Put `LC_ALL=C` in front of both, or export it.
- `-e 0` without `-o`: join only fills empty fields when the output fields are listed.

## Learn next
`join -v1` prints only the unpaired lines of file 1 (here, the idle customers on
their own). For a one-off report, an awk hash join needs no sorting at all:
`awk -F, 'NR==FNR {...; next} {...}' orders.csv customers.csv`.
