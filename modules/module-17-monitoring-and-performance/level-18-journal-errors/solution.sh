#!/bin/bash
jq -r 'select((.PRIORITY|tonumber)<=3) | "\(.__REALTIME_TIMESTAMP|tonumber/1000000|floor|strftime("%H:%M")) \(._SYSTEMD_UNIT // "-")"' journal.json > errs.txt
m=$(cut -d' ' -f1 errs.txt | uniq -c | awk '$1>10 {print $2; exit}')
u=$(grep "^$m " errs.txt | cut -d' ' -f2 | grep -v '^-$' | sort | uniq -c | sort -rn | awk 'NR==1 {print $2}')
echo "$m $u" > spike.txt
