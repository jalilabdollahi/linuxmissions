#!/bin/bash
# Same PID alive; app.log small, still written to and DEBUG-free; rotate.conf
# valid for logrotate -d, covering the real log, with copytruncate or a HUP.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
[ -s .lm-state/pid ] || { echo "❌ the level's data is gone; type 'reset'"; exit 1; }
pid=$(cat .lm-state/pid)
if ! kill -0 "$pid" 2>/dev/null || ! tr '\0' ' ' < /proc/$pid/cmdline 2>/dev/null | grep -q "$SANDBOX/app/app.py"; then
  echo "❌ the original app process (PID $pid) is not running any more; it must stay up, restarting it drops sessions"; exit 1
fi
log=app/app.log
if [ ! -f "$log" ]; then echo "❌ app/app.log does not exist; the app should be writing to it"; exit 1; fi
sz=$(stat -c %s "$log")
if [ "$sz" -gt 10240 ]; then echo "❌ app.log is still $((sz/1024)) KB; free the space it holds"; exit 1; fi
sleep 2.5
sz2=$(stat -c %s "$log" 2>/dev/null || echo 0)
if [ "$sz2" -le "$sz" ]; then
  echo "❌ app.log is not growing: the app must still be writing to the file at this path (does it hold a deleted file open?)"; exit 1
fi
if grep -q ' DEBUG ' "$log"; then
  echo "❌ the app is still writing DEBUG lines; find out where its level comes from and make it pick the change up"; exit 1
fi
if [ ! -f rotate.conf ]; then echo "❌ rotate.conf is missing"; exit 1; fi
out=$(logrotate -d -s "$SANDBOX/logrotate.state" "$SANDBOX/rotate.conf" 2>&1); rc=$?
if [ $rc -ne 0 ] || echo "$out" | grep -q '^error:'; then
  echo "❌ logrotate -d rejects rotate.conf: $(echo "$out" | grep -m1 -i 'error' | cut -c1-120)"; exit 1
fi
if ! echo "$out" | grep -q "considering log $SANDBOX/app/app.log"; then
  echo "❌ rotate.conf is valid but does not cover the file the app really writes"; exit 1
fi
if ! grep -q '^[[:space:]]*copytruncate' rotate.conf && ! { grep -q postrotate rotate.conf && grep -q HUP rotate.conf; }; then
  echo "❌ rotate.conf would rename the log under a running process; it needs copytruncate or a HUP in postrotate"; exit 1
fi
echo "✅ same app process, small DEBUG-free log still growing, and a rotate.conf logrotate accepts for the real log"
