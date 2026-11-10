# Whose Third Of November

## Why it works
Each style is recognised by its separator: `/` for day/month/year, a space
for `3 Nov 2026`, and `-` for ISO dates, which need no change. `split` breaks
the value into parts, a small array turns month names into numbers, and
`sprintf("%04d-%02d-%02d", ...)` builds a zero-padded ISO date from them.
Assigning to `$2` makes awk rebuild the line with `OFS`, so with `OFS=,` the
other columns, even a quoted "Okafor, Chinedu" that awk split in two, come out
exactly as they went in.

## Common mistakes
- `date -d 03/11/2026` (GNU date) reads it as 11 March without any warning;
  only days above 12 fail, and those are the minority.
- Forgetting `-v OFS=,`: the rebuilt line is joined with spaces.
- Zero-padding with string tricks instead of `%02d`, which leaves `2026-1-5`.

## Learn next
Once dates are ISO they sort and compare as text:
`awk -F, '$2 >= "2026-12-20" && $2 <= "2027-01-06"' bookings_iso.csv` lists
the holiday arrivals. GNU `date -d 2026-11-03 +%A` names the weekday, and
`date -d '2026-11-03 + 4 days' +%F` gives the checkout date.
