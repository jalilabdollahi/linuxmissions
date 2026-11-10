# Laggy VPN

## Why it works
`ping` ends with a summary: packets sent and received, the loss percentage,
and `rtt min/avg/max/mdev`. Loss shows broken or overloaded paths; mdev (mean
deviation of the round-trip times) is ping's jitter figure, and high jitter is
what makes voice and interactive sessions feel laggy even when the average is
fine. Finding the `%` field instead of counting fields mattered because ping
inserts `+N duplicates` and `+N errors` before the loss when it saw them, and a
site that never answered prints no rtt line at all.

## Common mistakes
- `awk '{print $6}'` on every summary: right for most files, wrong for the ones
  with duplicates or errors.
- Treating exactly 2 % (1 of 50) as "above 2 %".
- `print > "file"` inside awk run once per file: every run truncates the list again; use `>>`.

## Learn next
`ping -q -c 50 -i 0.2 HOST` prints only the summary (and runs faster).
`mtr --report -c 100 HOST` shows loss and jitter for every hop on the path, which
is how you find out *where* the loss starts (next level).
