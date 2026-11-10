#!/bin/bash
# Log Hunt: a mock journal (frozen clock: 2024-04-08 14:30:00) with entries
# from several units over two days. The player must pick myapp's err-or-worse
# entries since 14:00 today. Traps: "error" appears in info lines, real
# failures don't contain the word "error", nginx errors mention myapp, and
# yesterday's 14:xx entries exist too.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p var/log/journal

# date time <TAB> priority (0-7) <TAB> unit <TAB> identifier[pid] <TAB> message
cat > var/log/journal/system.journal <<'EOF'
2024-04-07 09:12:01	6	myapp.service	myapp[1180]	myapp 2.4.0 started, listening on :8080
2024-04-07 13:58:40	6	cron.service	CRON[1302]	(root) CMD (/usr/local/bin/backup.sh)
2024-04-07 14:10:22	3	myapp.service	myapp[1180]	database connection refused (db01:5432)
2024-04-07 14:11:05	6	myapp.service	myapp[1180]	database connection restored
2024-04-07 14:40:13	4	nginx.service	nginx[880]	worker_connections are not enough
2024-04-07 22:00:01	6	cron.service	CRON[1999]	(root) CMD (/usr/sbin/logrotate /etc/logrotate.conf)
2024-04-08 08:00:00	6	systemd-logind.service	systemd-logind[612]	New session 41 of user deploy.
2024-04-08 09:30:12	6	myapp.service	myapp[1180]	health check ok error_rate=0.00
2024-04-08 11:15:09	3	myapp.service	myapp[1180]	cache warmup failed: redis timeout after 5s
2024-04-08 12:00:00	6	myapp.service	myapp[1180]	health check ok error_rate=0.01
2024-04-08 13:41:55	4	myapp.service	myapp[1180]	slow query: SELECT * FROM orders took 2.3s
2024-04-08 13:52:30	3	myapp.service	myapp[1180]	error writing session file /var/lib/myapp/sess_91: disk quota exceeded
2024-04-08 13:59:58	6	systemd-logind.service	systemd-logind[612]	New session 42 of user deploy.
2024-04-08 14:00:04	6	myapp.service	myapp[1180]	received SIGTERM, shutting down for deploy
2024-04-08 14:00:06	6	systemd.service	systemd[1]	Stopped myapp.service - MyApp API server.
2024-04-08 14:00:09	6	systemd.service	systemd[1]	Started myapp.service - MyApp API server.
2024-04-08 14:00:10	6	myapp.service	myapp[2210]	myapp 2.4.1 starting, previous error count reset
2024-04-08 14:00:11	3	myapp.service	myapp[2210]	Failed to bind 0.0.0.0:8080: Address already in use
2024-04-08 14:00:12	4	myapp.service	myapp[2210]	retrying bind in 5s
2024-04-08 14:00:17	6	myapp.service	myapp[2210]	listening on :8080
2024-04-08 14:02:45	3	nginx.service	nginx[880]	connect() failed (111: Connection refused) while connecting to upstream myapp
2024-04-08 14:05:31	6	cron.service	CRON[2301]	(deploy) CMD (/opt/myapp/bin/report --errors-only)
2024-04-08 14:07:02	3	myapp.service	myapp[2210]	database connection refused (db01:5432)
2024-04-08 14:07:03	6	myapp.service	myapp[2210]	retrying database in 10s, error budget ok
2024-04-08 14:11:48	4	myapp.service	myapp[2210]	worker 3 using 1.8G of 2G memory limit
2024-04-08 14:12:20	2	myapp.service	myapp[2210]	Out of memory: worker 3 killed
2024-04-08 14:15:00	6	myapp.service	myapp[2210]	health check ok error_rate=0.04
2024-04-08 14:18:37	3	myapp.service	myapp[2210]	payment webhook rejected: invalid signature from 203.0.113.9
2024-04-08 14:20:01	3	sshd.service	sshd[3101]	error: maximum authentication attempts exceeded for root from 198.51.100.23
2024-04-08 14:24:59	6	myapp.service	myapp[2210]	health check ok error_rate=0.02
2024-04-08 14:29:30	5	myapp.service	myapp[2210]	config reloaded by deploy
EOF

cat > journalctl <<'SCRIPT'
#!/bin/bash
# Mock journalctl for LinuxMissions. Not the real journal: it reads
# ./var/log/journal/system.journal and its clock is frozen at
# 2024-04-08 14:30:00. Supports: -u/--unit, -p/--priority, -S/--since,
# -U/--until, -g/--grep, -n/--lines, -r/--reverse, -o short|short-iso|cat,
# -q, --no-pager.
ROOT="$(cd "$(dirname "$0")" && pwd)"
JOURNAL="$ROOT/var/log/journal/system.journal"
NOW="2024-04-08 14:30:00"

units=""; prio=""; since=""; until=""; pattern=""; lines=""; reverse=0; output="short"

die() { echo "$*" >&2; exit 1; }
need() { [ -n "$2" ] || die "journalctl: option '$1' requires an argument"; }

while [ $# -gt 0 ]; do
  case "$1" in
    -u|--unit) need "$1" "$2"; units="$units $2"; shift ;;
    --unit=*) units="$units ${1#*=}" ;;
    -u*) units="$units ${1#-u}" ;;
    -p|--priority) need "$1" "$2"; prio="$2"; shift ;;
    --priority=*) prio="${1#*=}" ;;
    -p*) prio="${1#-p}" ;;
    -S|--since) need "$1" "$2"; since="$2"; shift ;;
    --since=*) since="${1#*=}" ;;
    -U|--until) need "$1" "$2"; until="$2"; shift ;;
    --until=*) until="${1#*=}" ;;
    -g|--grep) need "$1" "$2"; pattern="$2"; shift ;;
    --grep=*) pattern="${1#*=}" ;;
    -n|--lines) need "$1" "$2"; lines="$2"; shift ;;
    --lines=*) lines="${1#*=}" ;;
    -o|--output) need "$1" "$2"; output="$2"; shift ;;
    --output=*) output="${1#*=}" ;;
    -r|--reverse) reverse=1 ;;
    -q|--quiet|--no-pager|--no-hostname) ;;
    -x|-e|-xe|-ex|--catalog|--pager-end) ;;
    -f|--follow) die "journalctl (mock): --follow is not supported in this sandbox" ;;
    -h|--help) sed -n '2,7p' "$0"; exit 0 ;;
    -*) die "journalctl: unrecognized option '$1'" ;;
    *) die "journalctl (mock): match expressions are not supported, use -u UNIT" ;;
  esac
  shift
done

case "$output" in short|short-iso|cat) ;; *) die "journalctl (mock): output mode '$output' is not supported (use short, short-iso or cat)" ;; esac
case "$lines" in ""|all|*[!0-9]*) [ -z "$lines" ] || [ "$lines" = all ] || die "Failed to parse lines '$lines'" ;; esac

# Turn a priority name/number (or FROM..TO range) into "min max".
prio_num() {
  case "$1" in
    0|emerg) echo 0 ;; 1|alert) echo 1 ;; 2|crit) echo 2 ;; 3|err) echo 3 ;;
    4|warning) echo 4 ;; 5|notice) echo 5 ;; 6|info) echo 6 ;; 7|debug) echo 7 ;;
    *) die "Unknown log level $1" ;;
  esac
}
pmin=0; pmax=7
if [ -n "$prio" ]; then
  case "$prio" in
    *..*) a="$(prio_num "${prio%%..*}")" || exit 1; b="$(prio_num "${prio##*..}")" || exit 1
          if [ "$a" -le "$b" ]; then pmin=$a; pmax=$b; else pmin=$b; pmax=$a; fi ;;
    *) pmax="$(prio_num "$prio")" || exit 1 ;;
  esac
fi

# Turn a systemd time spec into "YYYY-MM-DD HH:MM:SS" (April 2024 only).
parse_time() {
  awk -v spec="$1" -v now="$NOW" '
    function tosec(t,   d) { return substr(t,9,2)*86400 + substr(t,12,2)*3600 + substr(t,15,2)*60 + substr(t,18,2) }
    function fmt(s) { return sprintf("2024-04-%02d %02d:%02d:%02d", int(s/86400), int(s%86400/3600), int(s%3600/60), s%60) }
    function unit(u) {
      if (u ~ /^(s|sec|secs|second|seconds)$/) return 1
      if (u ~ /^(m|min|mins|minute|minutes)$/) return 60
      if (u ~ /^(h|hr|hour|hours)$/) return 3600
      if (u ~ /^(d|day|days)$/) return 86400
      return 0
    }
    BEGIN {
      s = spec; gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
      n = tosec(now)
      if (s == "now") { print now; exit }
      if (s == "today") { print fmt(int(n/86400)*86400); exit }
      if (s == "yesterday") { print fmt(int(n/86400)*86400 - 86400); exit }
      if (match(s, /^[0-9]+ ?[a-z]+ ago$/) || match(s, /^-[0-9]+ ?[a-z]+$/)) {
        t = s; sub(/ ago$/, "", t); sub(/^-/, "", t)
        num = t; sub(/[^0-9].*$/, "", num)
        u = t; sub(/^[0-9]+ ?/, "", u)
        if (unit(u) == 0) { print "ERR"; exit }
        print fmt(n - num * unit(u)); exit
      }
      if (s ~ /^[0-9][0-9]?:[0-9][0-9](:[0-9][0-9])?$/) { s = substr(now,1,10) " " s }
      if (s ~ /^today [0-9]/) { s = substr(now,1,10) substr(s,6) }
      if (s ~ /^yesterday [0-9]/) { s = fmt(int(n/86400)*86400 - 86400); s = substr(s,1,10) substr(spec, index(spec," ")) }
      if (s ~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/) s = s " 00:00:00"
      if (s ~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}[ T][0-9][0-9]?:[0-9]{2}(:[0-9]{2})?$/) {
        split(substr(s,12), hm, ":")
        print substr(s,1,10) sprintf(" %02d:%02d:%02d", hm[1], hm[2], hm[3]); exit
      }
      print "ERR"
    }'
}
s_from=""; s_to=""
if [ -n "$since" ]; then s_from="$(parse_time "$since")"; [ "$s_from" = ERR ] && die "Failed to parse timestamp: $since"; fi
if [ -n "$until" ]; then s_to="$(parse_time "$until")"; [ "$s_to" = ERR ] && die "Failed to parse timestamp: $until"; fi

want_units=""
for u in $units; do
  case "$u" in *.*) ;; *) u="$u.service" ;; esac
  want_units="$want_units $u "
done

out="$(awk -F'\t' -v units="$want_units" -v pmin="$pmin" -v pmax="$pmax" \
          -v from="$s_from" -v to="$s_to" -v pat="$pattern" -v mode="$output" '
  BEGIN { split("Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec", mon, " ") }
  {
    if (units != "" && index(units, " " $3 " ") == 0) next
    if ($2 < pmin || $2 > pmax) next
    if (from != "" && $1 < from) next
    if (to != "" && $1 > to) next
    if (pat != "" && $5 !~ pat) next
    if (mode == "cat") print $5
    else if (mode == "short-iso") print substr($1,1,10) "T" substr($1,12) "+0000 web01 " $4 ": " $5
    else print mon[substr($1,6,2)+0] " " substr($1,9,2) " " substr($1,12) " web01 " $4 ": " $5
  }' "$JOURNAL")"

if [ -z "$out" ]; then echo "-- No entries --"; exit 0; fi
if [ -n "$lines" ] && [ "$lines" != all ]; then out="$(printf '%s\n' "$out" | tail -n "$lines")"; fi
if [ "$reverse" = 1 ]; then printf '%s\n' "$out" | awk '{ a[NR] = $0 } END { for (i = NR; i >= 1; i--) print a[i] }'
else printf '%s\n' "$out"; fi
SCRIPT
chmod +x journalctl
