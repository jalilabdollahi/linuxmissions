#!/bin/bash
# Code and time per URL without following redirects; --max-time so the hung
# endpoint can't block the loop (curl prints 000 then).
grep -v -e '^#' -e '^$' endpoints.txt | while read -r url; do
  printf '%s\t%s\n' "$url" "$(curl -s -o /dev/null --max-time 5 -w '%{http_code}\t%{time_total}' "$url")"
done > status.tsv
awk -F'\t' '$2 !~ /^2/ || $3 > 1 { print $1 }' status.tsv > bad.txt
cat status.tsv bad.txt
