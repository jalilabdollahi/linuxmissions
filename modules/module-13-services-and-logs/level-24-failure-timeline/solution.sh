#!/bin/bash
# Each source to "UTC-TIME source message", cut to the window, syslog copies
# of journal lines removed, then one stable sort on the time only.
a=2026-11-09T23:30:00Z; b=2026-11-09T23:44:59Z      # 03:00:00-03:14:59 at +03:30
inwin() { awk -v a="$a" -v b="$b" '$1 >= a && $1 <= b'; }

# journal: microseconds since the epoch -> UTC seconds
jq -r '"\(.__REALTIME_TIMESTAMP | tonumber / 1e6 | floor | todate) journal \(.SYSLOG_IDENTIFIER)[\(._PID)]: \(.MESSAGE)"' \
  export/journal.json | inwin > j.txt

# syslog: "Nov 10 03:04:05 host text": add the year and the zone, drop the host
paste -d' ' \
  <(awk '{ print $1, $2, 2026, $3, "+0330" }' var/log/syslog | date -u -f - +%FT%TZ) \
  <(sed 's/^.\{15\} [^ ]* /syslog /' var/log/syslog) | inwin > s.all
grep -vxF -f <(sed 's/ journal / syslog /' j.txt) s.all > s.txt

# nginx: 5xx only; [10/Nov/2026:03:04:05 +0330] -> "10 Nov 2026 03:04:05 +0330"
paste -d' ' \
  <(awk '$9 >= 500 { t = substr($4, 2); sub(":", " ", t); gsub("/", " ", t); print t, substr($5, 1, 5) }' var/log/nginx/access.log | date -u -f - +%FT%TZ) \
  <(awk '$9 >= 500 { print "nginx", substr($6, 2), $7, $9 }' var/log/nginx/access.log) | inwin > n.txt

# app: WARN and ERROR, ISO 8601 with offset
grep -E '^[^ ]+ (WARN|ERROR) ' var/log/api/app.log > a.all
paste -d' ' <(cut -d' ' -f1 a.all | date -u -f - +%FT%TZ) <(cut -d' ' -f2- a.all | sed 's/^/app /') | inwin > a.txt

cat j.txt s.txt n.txt a.txt | LC_ALL=C sort -s -k1,1 > timeline.txt
rm -f j.txt s.all s.txt n.txt a.all a.txt
wc -l timeline.txt
