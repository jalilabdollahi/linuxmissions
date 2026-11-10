# One Timeline, Two Clocks

## Why it works
Unix time counts seconds since 1970-01-01 UTC; a 13-digit value is the same
clock in milliseconds, so `int($1 / 1000)` brings both logs to one unit.
gawk's `strftime(fmt, t, 1)` formats in UTC (the third argument), and an ISO
timestamp with fixed widths sorts the same as text and as time. Feeding
billing.log before notify.log and sorting with `-s -k1,1` orders by the
second only: for equal seconds the input order survives, which is billing
first and each log's own order.

## Common mistakes
- `date -d @1794319402518`: a date in the year 58829.
- Without `-s`, sort's last-resort comparison reorders equal seconds by the
  rest of the line, so a WARN that happened first ends up after an INFO.
- Forgetting `-u` / the UTC flag: on a machine set to another time zone every
  line shifts by hours.

## Learn next
Keep the milliseconds when you need sub-second order:
`strftime("%Y-%m-%dT%H:%M:%S", s, 1) sprintf(".%03dZ", ms % 1000)`. Correlating
logs from servers in different time zones (`+0100`, `-0500`) is the next step;
`date -u -d '2026-11-10 14:03:22 +0100'` normalises such times.
