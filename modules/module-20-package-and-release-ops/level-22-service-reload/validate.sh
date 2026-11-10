#!/bin/bash
# Same daemon process, config 1.5 live, deployed file valid and otherwise untouched, and the
# long-lived feed connection (started by setup) still open and flowing.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
PORT=$(cat .lm/port)
PID=$(cat .lm/pid)
if ! kill -0 "$PID" 2>/dev/null; then
  echo "❌ the original pricer process ($PID) is gone: it was restarted or it exited (an invalid config on SIGHUP makes it quit)"
  exit 1
fi
V=$(curl -s -m 3 "http://127.0.0.1:$PORT/version")
if [ -z "$V" ]; then
  echo "❌ pricer does not answer on 127.0.0.1:$PORT"
  exit 1
fi
if [ "$(echo "$V" | jq -r .pid)" != "$PID" ]; then
  echo "❌ the process answering on port $PORT is not the original daemon"
  exit 1
fi
OUT=$(python3 .lm/pricer.orig.py --check etc/pricer/pricer.conf 2>&1)
if [ $? -ne 0 ]; then
  echo "❌ etc/pricer/pricer.conf does not pass pricer --check: $(echo "$OUT" | head -1 | cut -c1-120)"
  exit 1
fi
norm() { sed -E 's/#.*//; s/[[:space:]]+//g; /^$/d' "$1" | sort; }
exp=$(sed -E "s/^markup_pct *= *[0-9]+%/markup_pct = $(cat .lm/new.markup)/" release-1.5/pricer.conf)
if [ "$(norm etc/pricer/pricer.conf)" != "$(echo "$exp" | sed -E 's/#.*//; s/[[:space:]]+//g; /^$/d' | sort)" ]; then
  echo "❌ etc/pricer/pricer.conf is valid but is not the 1.5 configuration with only the broken value fixed"
  exit 1
fi
if [ "$(echo "$V" | jq -r .config)" != "1.5" ]; then
  echo "❌ the running daemon still uses config $(echo "$V" | jq -r .config): make it re-read the file without restarting it"
  exit 1
fi
if [ "$(echo "$V" | jq -r .markup_pct)" != "$(cat .lm/new.markup)" ] || [ "$(echo "$V" | jq -r .reloads)" -lt 1 ]; then
  echo "❌ the daemon reports config 1.5 but not the new markup, or it never reloaded"
  exit 1
fi
if ! pgrep -f "$SANDBOX/.lm/stream.out" >/dev/null; then
  echo "❌ the customers' open feed connection was dropped: the daemon was restarted instead of reloaded"
  exit 1
fi
s1=$(stat -c %s .lm/stream.out 2>/dev/null || stat -f %z .lm/stream.out)
sleep 1.2
s2=$(stat -c %s .lm/stream.out 2>/dev/null || stat -f %z .lm/stream.out)
if [ "$s2" -le "$s1" ]; then
  echo "❌ the open feed connection stopped receiving data"
  exit 1
fi
if ! tail -1 .lm/stream.out | grep -q "markup=$(cat .lm/new.markup)"; then
  echo "❌ the open connection is not seeing the new setting yet"
  exit 1
fi
echo "✅ config 1.5 is live in the same process (PID $PID) and the open connection never dropped"
