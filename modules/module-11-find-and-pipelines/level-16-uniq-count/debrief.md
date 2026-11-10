# Is It Beaconing?

## Why it works
uniq never looks further than the previous line: it collapses *runs* of
identical lines. So the names had to become identical (`tr` for the case,
`sed 's/\.$//'` for the trailing dot, which DNS treats as the same name) and
adjacent (`sort`) before counting. Then `uniq -c` gives the count per run,
`uniq -u` keeps the names whose run has length 1, and `uniq -d` would print
one copy of every name that repeats. Filtering on `query\[` first matters:
each lookup is logged on two or three lines.

## Common mistakes
- `uniq -c` on unsorted data: the same domain appears many times with small
  counts, because only neighbours are merged.
- `uniq -i` instead of `tr`: it ignores case only for neighbours, so the input
  still has to be sorted case-insensitively (`sort -f`), and it does nothing
  about the trailing dot.
- `uniq -u` before normalising lists `example.com.` as "seen once" even when
  `example.com` was queried 20 times.

## Learn next
The regular spacing of the lookups is the real tell-tale sign of a beacon.
`grep -i 'query.*cdn-telemetry' dnsmasq.log | awk '{ print $3 }'` shows the
times; `uniq -c` also counts consecutive repeats in time-ordered data, which
is how you find bursts. `sort | uniq -c | sort -rn | head` is the classic "top
N" idiom; `awk '{ c[$1]++ } END { for (k in c) print c[k], k }'` does the same
count without sorting first.
