#!/bin/bash
# Re-run the original cron-sim against the original schedule on the player's
# crontab.txt and scripts; it must exit 0 (exact fired/done/first-run/exit
# codes per job, no overlapping backups, a report file).
SANDBOX="$1"
cd "$SANDBOX" || exit 1
[ -s .lm-state/schedule.tsv ] && [ -s .lm-state/cron-sim.orig ] && [ -f crontab.txt ] || { echo "❌ crontab.txt or the level data is missing; type 'reset'"; exit 1; }
out=$(python3 .lm-state/cron-sim.orig --root "$SANDBOX" --schedule .lm-state/schedule.tsv 2>&1); rc=$?
if [ $rc -eq 0 ]; then
  echo "✅ every job runs exactly as SCHEDULE.md says: right times, exit 0, no overlapping backups, report written"
  exit 0
fi
if echo "$out" | grep -q 'cron ignored'; then
  echo "❌ cron refuses crontab.txt: $(echo "$out" | sed -n 2p)"; exit 1
fi
line=$(echo "$out" | grep -m1 -- '<-- differs')
if [ -n "$line" ]; then
  j=$(echo "$line" | awk '{print $1}')
  echo "❌ job '$j' does not run as scheduled (fired/done/exit/first run: $(echo "$line" | awk '{print $2"/"$3"/"$4"/"}') vs what SCHEDULE.md expects); check how cron would run it"; exit 1
fi
if echo "$out" | grep -q 'overlapped: YES'; then echo "❌ two backups ran at the same time"; exit 1; fi
if echo "$out" | grep -q 'report file: missing'; then echo "❌ the report file reports/report-YYYY-MM-DD.txt is missing or empty"; exit 1; fi
echo "❌ the simulated day does not match SCHEDULE.md: $(echo "$out" | tail -1)"; exit 1
