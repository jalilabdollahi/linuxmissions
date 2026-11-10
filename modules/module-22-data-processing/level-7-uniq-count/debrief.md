# Longest Outage

## Why it works
`uniq -c` merges *adjacent* identical lines only, so on the unsorted status
column each output line is one run: `14 DOWN` is fourteen DOWN probes in a
row. Sorting first destroys that: `sort | uniq -c` adds every DOWN of the day
into one number. The awk version keeps a counter that grows on each DOWN line
and resets on UP, notes the timestamp when the counter starts from zero, and
remembers the best run seen so far.

## Common mistakes
- `sort | uniq -c`: the total DOWN minutes of the day, including the flapping
  hour, not the longest outage.
- `uniq -c` on status *and* error: the long outage changed from timeout to
  connection refused, which splits it into three shorter runs.
- Updating the best run only when an UP line arrives: a run that lasts until
  the end of the file is never counted.

## Learn next
`uniq -c` on a time-ordered column is a quick run-length encoding: try it on
`journalctl` output or a CI history. `awk '{ print $2 }' probe.log | uniq -c | awk '$2 == "DOWN"' | sort -n | uniq -c`
turns the runs into a histogram of outage lengths.
