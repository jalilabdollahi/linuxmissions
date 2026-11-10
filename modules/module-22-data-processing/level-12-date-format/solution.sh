#!/bin/bash
# Rewrite only $2. d/m/y -> y-m-d; "d Mon y" via a month-name table; ISO stays.
awk -F, -v OFS=, '
  BEGIN { split("Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec", names, " "); for (i = 1; i <= 12; i++) mon[names[i]] = i }
  NR > 1 && $2 ~ /\// { split($2, p, "/"); $2 = sprintf("%04d-%02d-%02d", p[3], p[2], p[1]) }
  NR > 1 && $2 ~ / /  { split($2, p, " "); $2 = sprintf("%04d-%02d-%02d", p[3], mon[p[2]], p[1]) }
  { print }' bookings.csv > bookings_iso.csv
cut -d, -f2 bookings_iso.csv | sort | uniq -c | sort -rn | head -3
