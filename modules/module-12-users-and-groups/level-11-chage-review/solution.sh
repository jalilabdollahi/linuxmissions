#!/bin/bash
# Field 3 = last change (days since 1970), field 5 = max age. Expiry day = f3 + f5,
# listed when it is on or before today + 14 (2026-11-10, as a day number).
today=$(( $(date -u -d 2026-11-10 +%s) / 86400 ))
bin/chage -l "$(awk -F: "NR == 5 { print \$1 }" etc/shadow)"
awk -F: -v t="$today" '$3 != "" && $5 != "" && $5 < 99999 { e = ($3 == 0) ? t : $3 + $5; if (e <= t + 14) print e, $1 }' etc/shadow \
  | sort -n \
  | while read -r d u; do echo "$u $(date -u -d "1970-01-01 +$d days" +%F)"; done > expiring.txt
cat expiring.txt
