#!/bin/bash
mp=$(awk 'NR>1 && $5=="100%" {print $6}' captured/df-i.txt)
dir=$(find spool -type f -printf '%h\n' | sort | uniq -c | sort -rn | head -1 | sed -E 's/^ *[0-9]+ //')
echo "$mp $dir" > culprit.txt
