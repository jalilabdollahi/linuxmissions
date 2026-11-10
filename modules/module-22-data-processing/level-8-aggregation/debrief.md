# Per-Endpoint API Stats

## Why it works
`sub(/\?.*/, "", ep)` cuts the url at the first `?`, so all
`/api/users?id=...` requests collapse into `/api/users`. awk arrays indexed by
that endpoint hold several running values at once: a count, two sums and a
maximum. The average is computed only at the end (`sum / count`), and
`printf "%.1f"` rounds it. A `-` in the bytes column is a string that awk
treats as 0 in arithmetic, which is what "no body" means.

## Common mistakes
- Grouping on the full url: hundreds of "endpoints", one per query string.
- Averaging averages, or rounding before summing: compute from the raw sums.
- Storing the maximum from a string operation (e.g. after `substr`): then
  `"987" > "1203"` is a text comparison and the maximum is wrong. Fields and
  numbers compare numerically.
- Sorting the whole file, header included: print the header separately.

## Learn next
Percentiles need all the values, not a running sum: collect latencies per
endpoint, `sort -n` them, and pick the value at 95% of the count. Tools like
`datamash -g 1 count 1 mean 7 max 7` (not installed here) do this kind of
group-by in one command.
