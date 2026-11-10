#!/bin/bash
cat df-i.txt
dir=$(find var -type f -printf '%h\n' | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')
echo "$dir" > report.txt
find "$dir" -type f -mtime +0 -delete
find "$dir" -type f | wc -l
