# Retiring netstat

## Why it works
`ss -tan` reports the same sockets as `netstat -tan`, but spells the states
its own way (`ESTAB`, `TIME-WAIT`, `FIN-WAIT-2`) and prints a single header
line, not two. The rewrite skips the header, translates each name back to the
netstat spelling in awk, counts per state and keeps the old `sort`, so the
output is byte-identical and nothing downstream has to change.

## Common mistakes
- Forgetting `NR>1`: the header is counted as a state called `State`.
- Translating only ESTAB and TIME-WAIT: FIN-WAIT-2 and CLOSE-WAIT then differ
  and the dashboards silently lose a series.
- Replacing every hyphen but not netstat's odd `FIN_WAIT2` (no underscore before the 2).

## Next step
`ss -s` gives a summary by state directly, `ss -tan state established`
filters in the kernel, and `ss -o` shows timers. For machine parsing,
`ss -H` suppresses the header altogether.
