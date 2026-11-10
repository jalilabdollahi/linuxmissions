#!/bin/bash
# Bring both files into one shape (lowercase id, amount in cents), then
# answer each section with sort/uniq/comm/join and awk for the sums.
export LC_ALL=C
head -3 source.csv loaded.tsv
wc -l source.csv loaded.tsv
awk -F, 'NR > 1 { printf "%s %.0f\n", $1, $NF * 100 }' source.csv | sort > src.ids
awk -F'\t' 'NR > 1 { print tolower($1), $3 }' loaded.tsv | sort > load.ids
{
  echo "[missing]"
  comm -23 <(cut -d' ' -f1 src.ids) <(cut -d' ' -f1 load.ids | sort -u)
  echo "[duplicated]"
  cut -d' ' -f1 load.ids | uniq -d
  echo "[changed]"
  join src.ids <(sort -u load.ids) | awk '$2 != $3 { printf "%s %.2f %.2f\n", $1, $2 / 100, $3 / 100 }'
  echo "[totals]"
  awk '{ s += $2 } END { printf "source %.2f\n", s / 100 }' src.ids
  awk '{ s += $2 } END { printf "loaded %.2f\n", s / 100 }' load.ids
} > audit.txt
rm src.ids load.ids
cat audit.txt
