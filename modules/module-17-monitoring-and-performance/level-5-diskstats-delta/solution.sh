#!/bin/bash
awk 'NR==FNR {before[$3]=$10; next} $3 ~ /^(sd[a-z]|nvme[0-9]+n[0-9]+)$/ {printf "%s %d\n", $3, ($10 - before[$3]) * 512 / 1024 / 10}' diskstats.1 diskstats.2 | sort -k2 -rn | head -1 > busiest.txt
