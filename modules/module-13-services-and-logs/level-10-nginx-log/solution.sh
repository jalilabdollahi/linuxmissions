#!/bin/bash
grep log_format -A 2 etc/nginx/nginx.conf
head -3 var/log/nginx/access.log
# $4 = [10/Nov/2026:HH:MM:SS, $7 = URL, $9 = status, $NF = upstream time
awk '{ split($4, t, ":"); if (t[2] ":" t[3] ":" t[4] < "14:00:00") next
       if ($9 !~ /^5/) next
       path = $7; sub(/\?.*/, "", path)
       n[path]++
       if ($NF != "-" && $NF + 0 > max[path]) max[path] = $NF + 0 }
     END { for (p in n) print p, n[p], max[p] }' var/log/nginx/access.log | sort -k2,2nr | head -1 > worst.txt
cat worst.txt
