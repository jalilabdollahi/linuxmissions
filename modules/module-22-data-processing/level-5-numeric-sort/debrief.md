# Hottest Readings

## Why it works
`-k3,3` limits the sort key to the value column. `-g` converts each key with
the C library's `strtod`, the same function programs use to read numbers, so
`1.2e3`, `4.75E2`, `-3.5` and `12` all become real numbers. `-r` puts the
largest first and `head -n 10` keeps the top ten.

## Common mistakes
- `sort -n` reads only the digits before the `e`: `1.2e3` sorts as 1.2, so
  the biggest spikes vanish from the top.
- A plain text sort compares characters: `9` comes after `12` and `-40` is
  ordered by its digits.
- `-k3` without `,3` means "from field 3 to the end of the line": harmless
  here, but wrong as soon as another column follows.

## Learn next
`-g` is slower than `-n`, so use it only when the data may contain exponents,
`inf` or `nan`. To see which formats a column holds, try
`cut -d, -f3 readings.csv | grep -c '[eE]'`. `sort -h` is the variant for
human sizes like `2K`, `1.5G`.
