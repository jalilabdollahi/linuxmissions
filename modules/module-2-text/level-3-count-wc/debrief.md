# By the Numbers

## What you practiced
- `wc -l` counts lines; `-w` words; `-c` bytes
- `awk '{print $N}'` extracts field N (whitespace-separated by default)
- `awk '{sum += $N} END {print sum}'` sums a numeric column
- `sort -u` deduplicates (same as `sort | uniq`)

## Commands to remember
```bash
wc -l file                              # count lines
awk '{print $1}' file | sort -u | wc -l # unique values in column 1
awk '{sum += $4} END {print sum}' file  # sum column 4
awk '{print $NF}' file                  # last field of each line
awk -F: '{print $1}' /etc/passwd        # colon-separated fields
```
