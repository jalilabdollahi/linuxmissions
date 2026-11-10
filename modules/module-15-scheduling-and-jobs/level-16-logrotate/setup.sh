#!/bin/bash
# The Log That Won't Let Go: app.log is huge and the app keeps it open (a
# background writer appends to it through one long-lived file descriptor).
# Older rotations already exist: app.log.1 plain, app.log.2-6.gz.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm .app

gen_log() {   # gen_log DAY LINES SEED
  awk -v day="$1" -v n="$2" -v seed="$3" 'BEGIN {
    srand(seed); split("INFO INFO INFO INFO WARN ERROR", lv, " ");
    split("/api/orders /api/cart /api/login /healthz /api/search /static/app.js", ep, " ");
    for (i = 0; i < n; i++) {
      s = i * 86400 / n;
      printf "%s %02d:%02d:%02d %s req=%d path=%s ms=%d\n", day, s/3600, (s%3600)/60, s%60,
        lv[int(rand()*6)+1], 100000 + i, ep[int(rand()*6)+1], int(rand()*900)+3
    }
  }'
}

gen_log 2026-11-09 52000 7 > app.log
gen_log 2026-11-08 4000 11 > .lm/old1
gen_log 2026-11-07 3800 13 > .lm/old2
gen_log 2026-11-06 3600 17 > .lm/old3
gen_log 2026-11-05 3500 19 > .lm/old4
gen_log 2026-11-04 3300 23 > .lm/old5
gen_log 2026-11-03 3100 29 > .lm/old6
cp .lm/old1 app.log.1
for i in 2 3 4 5 6; do gzip -c .lm/old$i > app.log.$i.gz; done
size=$(wc -c < app.log | tr -d ' ')
echo "$size" > .lm/size
head -c "$size" app.log | sha256sum | cut -d' ' -f1 > .lm/new.sha
for i in 1 2 3 4; do sha256sum < .lm/old$i | cut -d' ' -f1 > .lm/old$i.sha; done
rm -f .lm/old1 .lm/old2 .lm/old3 .lm/old4 .lm/old5 .lm/old6

cat > .app/writer.sh <<'W'
#!/bin/bash
# the application's log writer: opens app.log once (append) and keeps it open
cd "$1" || exit 1
echo $$ > .lm/writer.pid
trap '' HUP USR1
exec 3>>app.log
n=0
while :; do
  n=$((n + 1))
  echo "$(date '+%F %T') INFO live seq=$n" >&3
  sleep 0.2
done
W
chmod +x .app/writer.sh
setsid bash "$SANDBOX/.app/writer.sh" "$SANDBOX" >/dev/null 2>&1 </dev/null &
for _ in 1 2 3 4 5 6 7 8 9 10; do [ -s .lm/writer.pid ] && break; sleep 0.1; done

cat > TICKET.txt <<'EOF'
OPS-2290  app.log is eating the disk

app.log has grown to a few hundred MB (this sandbox has a scaled-down copy) and
nobody rotates it. Older rotations app.log.1 ... app.log.6.gz are from a manual
attempt in the spring.

The app (the writer started from .app/writer.sh) opens app.log once and keeps it
open. It cannot be restarted or signalled during the day, and every line it
writes matters.

Wanted: a logrotate config for app.log, and a rotation done now.
  * keep 5 old logs; the newest one stays uncompressed, the rest are gzipped
  * the state file is logrotate.state in this directory (we are not root)
  * try it with logrotate -d first: it changes nothing
EOF
