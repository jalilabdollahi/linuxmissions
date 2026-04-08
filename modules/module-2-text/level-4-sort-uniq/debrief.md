# Top Talkers

## What you practiced
The `sort | uniq -c | sort -rn` pipeline is a classic — memorize it:
1. `sort` — group duplicates together (uniq needs sorted input)
2. `uniq -c` — count consecutive duplicates, prefix each line with count
3. `sort -rn` — sort numerically in reverse (highest count first)

## Commands to remember
```bash
sort file | uniq -c | sort -rn          # frequency count, ranked
sort -u file                             # sort and deduplicate
sort -k2 -t: file                        # sort by field 2, colon separator
sort -rn numbers.txt                     # reverse numeric sort
uniq -d file                             # show only duplicate lines
uniq -u file                             # show only unique lines
```
