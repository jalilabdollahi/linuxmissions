#!/bin/bash
head -3 var/log/syslog
grep -m3 'message repeated' var/log/syslog
awk '$3 >= "02:00:00" && $3 <= "02:59:59" {
       prog = $5; sub(/\[[0-9]+\]/, "", prog); sub(/:$/, "", prog)
       n = ($6 == "message" && $7 == "repeated") ? $8 : 1
       count[prog] += n
     }
     END { for (p in count) print count[p], p }' var/log/syslog | sort -rn | head -3 > top-programs.txt
cat top-programs.txt
