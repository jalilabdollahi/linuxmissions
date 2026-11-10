# The Minute It Broke

## Why it works
`journalctl -o json` prints one object per entry with every value as a string.
`__REALTIME_TIMESTAMP` is microseconds since the epoch, so dividing by
1 000 000 and formatting with `strftime("%H:%M")` buckets entries by minute
(in UTC). Priority is a syslog level where lower means worse: `err` is 3, but
`crit` (2) and `alert` (1) are errors too. Because the export is in time
order, `uniq -c` counts entries per minute, `awk '$1>10'` finds the first
bucket over the threshold, and a second pass counts units inside just that
minute.

## Common mistakes
- `PRIORITY == "3"` misses crit/alert entries and may skip the real spike.
- Counting warnings (4) as errors makes an earlier, harmless minute look like the spike.
- Using the busiest unit of the whole hour instead of within the spike minute.
- Using `>= 10`: a minute with exactly 10 errors is below the threshold.

## Next step
`journalctl -p err --since "1 hour ago" -u billing.service` filters in
journalctl itself, and `-o json-pretty` or `-o cat` change the format.
