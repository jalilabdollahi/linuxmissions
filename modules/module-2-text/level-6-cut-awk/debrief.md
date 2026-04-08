# Column Harvest

## What you practiced
- `cut -d, -f1,3` — field separator `,`, extract fields 1 and 3
- `awk -F, '{print $1","$3}'` — same idea but with awk's power for formatting
- `awk` can reorder fields, compute values, and add custom delimiters

## cut vs awk
| Feature | cut | awk |
|---------|-----|-----|
| Simple extraction | Great | Works |
| Reorder fields | No | Yes |
| Math/logic | No | Yes |
| Multi-char delimiters | No | Yes |

## Commands to remember
```bash
cut -d: -f1 /etc/passwd            # extract usernames
cut -d, -f1,3 file.csv             # columns 1 and 3
awk -F, '{print $1,$3}' file.csv   # space-separated output
awk -F, 'NR>1 {print $1}' file     # skip header line
awk '{print $NF}' file             # last field
```
