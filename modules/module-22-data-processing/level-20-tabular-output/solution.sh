#!/bin/bash
# One awk program: skip the comment, the header and empty lines; trim the
# name, cut long ones to 19 characters plus ~; print fixed-width columns.
cat -A costs.csv
awk -F, '
  BEGIN { rule = "-------------------- ------------"; printf "%-20s %12s\n", "TEAM", "COST (USD)"; print rule }
  /^#/ || NR == 2 || NF < 2 { next }
  { name = $1; gsub(/^ +| +$/, "", name)
    if (length(name) > 20) name = substr(name, 1, 19) "~"
    cost = $2 + 0; total += cost
    printf "%-20s %12.2f\n", name, cost }
  END { print rule; printf "%-20s %12.2f\n", "TOTAL", total }' costs.csv > report.txt
cat report.txt
