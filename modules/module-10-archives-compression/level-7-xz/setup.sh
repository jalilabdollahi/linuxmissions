#!/bin/bash
# Month by Month: daily logs 2026-05-01 .. 2026-11-10. Each log is closed at
# midnight, so its mtime is the NEXT day: the last log of every month has an
# mtime in the following month.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p logs .lm-state

days_in() { case "$1" in 05|07|08|10) echo 31 ;; 06|09) echo 30 ;; 11) echo 10 ;; esac; }
for m in 05 06 07 08 09 10 11; do
  last=$(days_in "$m")
  for d in $(seq -w 1 "$last"); do
    f="logs/app-2026-$m-$d.log"
    awk -v day="2026-$m-$d" -v seed="$RANDOM$m$d" 'BEGIN {
      srand(seed)
      split("INFO INFO INFO INFO WARN ERROR", lv, " ")
      split("report.build report.mail scheduler db.pool cache.flush export.csv", src, " ")
      n = 40 + int(rand() * 120)
      for (i = 0; i < n; i++) {
        t = int(i * 86400 / n)
        printf "%s %02d:%02d:%02d %-5s %s job=%05d took=%dms\n", day, t/3600, (t%3600)/60, t%60,
          lv[1+int(rand()*6)], src[1+int(rand()*6)], int(rand()*99999), int(rand()*5000)
      }
    }' > "$f"
    # mtime: just after midnight of the following day
    if [ "$d" -eq "$last" ]; then
      nm=$(printf '%02d' $(( 10#$m + 1 ))); stamp="2026${nm}010000.$(printf '%02d' $(( RANDOM % 50 + 3 )))"
    else
      stamp="2026${m}$(printf '%02d' $(( 10#$d + 1 )))0000.$(printf '%02d' $(( RANDOM % 50 + 3 )))"
    fi
    touch -t "$stamp" "$f"
    echo "$(basename "$f") $(cksum < "$f")" >> .lm-state/logs.sums
  done
done
