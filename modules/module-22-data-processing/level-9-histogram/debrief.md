# Load Test Histogram

## Why it works
`int($2 / 100)` maps each response time to its bucket: 0-99 is 0, 100-199 is
1, and a value of exactly 100 is 1.0, so it lands in the higher bucket as it
should. Capping at 10 merges the long tail into `1000+`. The counts live in
an array, but printing walks a numeric loop over 0..10, so buckets that never
got a request still print, as 0 (an unset awk variable is 0 in a number
context). The bar is built by appending `#` once per full 10 requests.

## Common mistakes
- `for (b in count)`: only buckets that were seen, in no particular order.
- Comparing ranges by hand with `<=` (`$2 <= 100`): 100 lands one bucket too low.
- Counting the header line: `int("elapsed" / 100)` is 0, so 0-99 gets one extra.
- Using Latency (time to first byte) instead of elapsed (the whole response).

## Learn next
A log scale often shows latency better: `b = int(log($2) / log(2))` buckets
by powers of two. For several labels side by side, key the array as
`count[$3, b]` and print one histogram per endpoint.
