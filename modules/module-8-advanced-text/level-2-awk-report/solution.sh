#!/bin/bash
# Skip the header (NR > 1) and rows without a category (blank line, TOTAL footer);
# sum column 4 per column 3; print with cents; sort numerically on the total, largest first.
awk -F, 'NR > 1 && $3 != "" { sum[$3] += $4 } END { for (c in sum) printf "%s %.2f\n", c, sum[c] }' expenses.csv \
  | sort -k2,2nr > totals.txt
cat totals.txt
