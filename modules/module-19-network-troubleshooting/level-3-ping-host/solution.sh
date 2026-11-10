#!/bin/bash
rm -f lossy.txt jittery.txt
for f in pings/*.txt; do
  site=$(basename "$f" .txt)
  awk -v s="$site" '
    /packet loss/ { for (i = 1; i <= NF; i++) if ($i ~ /%$/) { sub(/%/, "", $i); if ($i + 0 > 2) print s >> "lossy.txt" } }
    /^rtt/        { split($4, v, "/"); if (v[4] + 0 > 20) print s >> "jittery.txt" }' "$f"
done
touch lossy.txt jittery.txt
head lossy.txt jittery.txt
