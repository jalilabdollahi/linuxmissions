#!/bin/bash
# After "logrotate -f -s logrotate.state logrotate.conf":
#  - the writer started by setup (same PID) still runs and appends to app.log;
#  - app.log.1 starts with the old giant log and is plain text; app.log.2-5.gz
#    are the previous rotations in order; there is no app.log.6*;
#  - app.log is small again and grows, app.log.1 does not grow;
#  - the state file records app.log, dated today.
SANDBOX="$(cd "$1" && pwd)"
cd "$SANDBOX" || exit 1
sha() { sha256sum 2>/dev/null | cut -d' ' -f1 || shasum -a 256 | cut -d' ' -f1; }

wpid=$(cat .lm/writer.pid 2>/dev/null)
if [ -z "$wpid" ] || ! kill -0 "$wpid" 2>/dev/null; then
  echo "❌ the application's writer is no longer running; it must keep running through the rotation (type reset to start over)"
  exit 1
fi
if [ ! -s logrotate.conf ]; then
  echo "❌ logrotate.conf does not exist yet"
  exit 1
fi
if [ ! -s logrotate.state ] || ! grep -q "app\.log\" " logrotate.state; then
  echo "❌ logrotate.state has no record of app.log: nothing has been rotated with it yet"
  exit 1
fi
# date in the state file: "/path/app.log" 2026-11-10-12:0:0
sd=$(awk '/app\.log" / { split($2, a, "-"); printf "%04d-%02d-%02d", a[1], a[2], a[3] }' logrotate.state | head -c 10)
if [ "$sd" != "$(date +%F)" ]; then
  echo "❌ logrotate.state says app.log was last rotated on ${sd:-an unknown date}, not today; rotate it now (-f)"
  exit 1
fi

if [ ! -f app.log.1 ]; then
  if [ -f app.log.1.gz ]; then
    echo "❌ app.log.1 was compressed at once; the newest old log should stay uncompressed until the next rotation"
  else
    echo "❌ there is no app.log.1: the log has not been rotated"
  fi
  exit 1
fi
if [ "$(head -c 2 app.log.1 | od -An -tx1 | tr -d ' \n')" = "1f8b" ]; then
  echo "❌ app.log.1 is gzip data, but the newest old log should be plain text"
  exit 1
fi
size=$(cat .lm/size)
if [ "$(head -c "$size" app.log.1 | sha)" != "$(cat .lm/new.sha)" ]; then
  echo "❌ app.log.1 does not start with the old content of app.log: it is not the rotated log"
  exit 1
fi
for i in 2 3 4 5; do
  if [ ! -f "app.log.$i.gz" ]; then
    echo "❌ app.log.$i.gz is missing: older logs must be kept (5 old logs) and gzipped"
    exit 1
  fi
done
for i in 1 2 3 4; do
  j=$((i + 1))
  if [ "$(gzip -dc "app.log.$j.gz" 2>/dev/null | sha)" != "$(cat .lm/old$i.sha)" ]; then
    echo "❌ app.log.$j.gz does not hold the log that was app.log.$i before: the old logs must shift up by one"
    exit 1
  fi
done
if ls app.log.[6-9]* app.log.[1-9][0-9]* >/dev/null 2>&1; then
  echo "❌ there are more than 5 old logs ($(ls app.log.[6-9]* app.log.[1-9][0-9]* | head -n 1) and maybe more); the oldest must be removed"
  exit 1
fi

if [ ! -f app.log ]; then
  w1=$(wc -c < app.log.1 | tr -d ' ')
  sleep 1.2
  if [ "$(wc -c < app.log.1 | tr -d ' ')" -ne "$w1" ]; then
    echo "❌ app.log.1 is still growing and app.log is gone: the app keeps writing into the renamed file"
  else
    echo "❌ app.log does not exist after the rotation"
  fi
  exit 1
fi
cur=$(wc -c < app.log | tr -d ' ')
if [ "$cur" -gt $((size / 2)) ]; then
  echo "❌ app.log is still $cur bytes: the old content is still in it"
  exit 1
fi
a1=$(wc -c < app.log.1 | tr -d ' ')
sleep 1.2
if ! kill -0 "$wpid" 2>/dev/null; then
  echo "❌ the application's writer stopped"
  exit 1
fi
b1=$(wc -c < app.log.1 | tr -d ' ')
if [ "$b1" -ne "$a1" ]; then
  echo "❌ app.log.1 is still growing: the app writes into the rotated file instead of app.log"
  exit 1
fi
if ! tail -n 3 app.log | grep -q ' live seq='; then
  echo "❌ the app's new lines do not appear in app.log (is it empty after the rotation?)"
  exit 1
fi
if ! logrotate -d -s "$SANDBOX/.lm/dry.state" logrotate.conf >/dev/null 2>&1; then
  echo "❌ logrotate.conf has errors (check it with logrotate -d -s logrotate.state logrotate.conf)"
  exit 1
fi
echo "✅ app.log rotated with 5 old logs and the app's writer never noticed"
exit 0
