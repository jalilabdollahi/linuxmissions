#!/bin/bash
last=$(grep -v '\* \* \*' traceroute.txt | tail -n 1 | grep -o '([0-9.]*)' | head -n 1 | tr -d '()')
jump=$(awk '$2 != "???" && $1 ~ /\|--/ { if (prev != "" && $6 - prev > 50) { print $1 + 0; exit } prev = $6 }' mtr-report.txt)
printf 'LAST_HOP=%s\nJUMP_HOP=%s\n' "$last" "$jump" > path.env
cat path.env
