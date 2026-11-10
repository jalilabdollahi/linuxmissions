# By the Numbers

## Why it works
One request per line makes `wc -l` the request count. `awk` splits each line on
whitespace, so `$1` is the client IP and `$10` the response size (the date,
request and status take fields 4 to 9). `sort -u | wc -l` counts distinct
values, and awk's `sum += $10` adds a column; awk treats `-` as 0, which is what
nginx means by it (a 304 response has no body).

## Common mistakes
- Using `$NF` (last field) for the size: in combined format the last field is
  the user agent, which contains spaces.
- `uniq` without `sort`: uniq only merges *adjacent* duplicates, so it over-counts.
- On macOS, `wc -l < file` prints leading spaces; that is harmless here, but
  `$(( $(wc -l < f) ))` or `| tr -d ' '` cleans it if a tool complains.

## Learn next
`awk '{n[$1]++} END {print length(n)}'` counts distinct IPs in one pass, and
`awk '{s+=$10} END {printf "%.1f MB\n", s/1048576}'` formats the total.
`cut -d' ' -f1` also extracts the IP when fields are separated by single spaces.
