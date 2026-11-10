#!/bin/bash
# For every regular account: find its lastlog line, convert the date to UTC,
# keep it if it is on or before the cut-off (or if there is no login at all).
: > dormant.txt
for u in $(awk -F: '$3 >= 1000 && $3 <= 59999 { print $1 }' etc/passwd); do
  latest=$(grep "^$u " lastlog.txt | cut -c44-)
  if [ -z "$latest" ] || [ "$latest" = '**Never logged in**' ]; then
    echo "$u never" >> dormant.txt
  else
    d=$(date -u -d "$latest" +%F)
    [[ "$d" > 2026-08-12 ]] || echo "$u $d" >> dormant.txt
  fi
done
cat dormant.txt
