# Top Talkers

## Why it works
`sort | uniq -c | sort -rn` is the standard Unix frequency count. `uniq` only
compares each line with the one before it, so the first `sort` must put identical
IPs next to each other. `uniq -c` prefixes each group with its size, and
`sort -rn` ranks by that number. The same pipeline answers "most common error",
"busiest URL" or "most used command" if you change what goes in.

## Common mistakes
- `uniq -c` without sorting first: the same IP appears in many small groups.
- `sort -r` without `-n`: text sorting puts `9` above `143`, because it compares
  character by character.
- Running the IP through `sort -u` first: that removes the duplicates you wanted to count.

## Learn next
`... | sort -rn | head -10` keeps the top ten, and
`awk '{n[$1]++} END {for (ip in n) print n[ip], ip}' access.log | sort -rn`
does the counting in awk alone. `sort -k2` sorts by the second column.
