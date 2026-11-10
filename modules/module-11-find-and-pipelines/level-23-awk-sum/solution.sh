#!/bin/bash
# Tab-separated fields: 1 path, 2 user, 3 bytes, 4 date. Sum per user in two
# arrays, print GiB with two decimals, sort numerically on column 2.
awk -F'\t' 'NF == 4 { total[$2] += $3; if ($4 < "2025-01-01") stale[$2] += $3 }
  END { for (u in total) printf "%s\t%.2f\t%.2f\n", u, total[u] / 1024^3, stale[u] / 1024^3 }' files.lst \
  | sort -t "$(printf '\t')" -k2,2nr > usage.txt
cat usage.txt
