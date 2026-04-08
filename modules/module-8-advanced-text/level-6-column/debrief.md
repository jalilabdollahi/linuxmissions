# Pretty Table

## What you practiced
Readable output matters. Column alignment makes reports much easier to scan, especially when multiple fields have different widths.

## Commands to remember
```bash
column -t report.txt
awk '{printf "%-10s %-10s %s\n", $1, $2, $3}'
printf "%-10s %-10s %s\n" "NAME" "STATUS" "PORT"
```
