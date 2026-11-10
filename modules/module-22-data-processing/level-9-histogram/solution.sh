#!/bin/bash
# Bucket = int(elapsed / 100), capped at 10; then print all 11 buckets in END.
awk -F, 'NR > 1 { b = int($2 / 100); if (b > 10) b = 10; count[b]++ }
END {
  for (i = 0; i <= 10; i++) {
    if (i < 10) label = (i * 100) "-" (i * 100 + 99); else label = "1000+"
    bar = ""
    for (j = 1; j <= int(count[i] / 10); j++) bar = bar "#"
    printf "%s %d %s\n", label, count[i], bar
  }
}' results.jtl > histogram.txt
cat histogram.txt
