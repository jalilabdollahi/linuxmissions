#!/bin/bash
echo "host,sockets,cores,threads" > licence.csv
for f in capture/*.cpuinfo; do
  h=$(basename "$f" .cpuinfo)
  awk -F': *' -v h="$h" '
    /^processor/  { t++ }
    /^physical id/ { p = $2; s[p] = 1 }
    /^core id/    { c[p ":" $2] = 1 }
    END { print h "," length(s) "," length(c) "," t }' "$f"
done >> licence.csv
cat licence.csv
