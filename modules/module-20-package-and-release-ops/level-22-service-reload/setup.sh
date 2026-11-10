#!/bin/bash
# Service Reload: starts bin/pricer (level-local helper pricer.py, a small HTTP daemon) on a random
# port, plus a long-lived "customer" feed connection. release-1.5/pricer.conf has one error
# ('markup_pct = N%'). A restart would drop the feed; a HUP with the broken file kills the daemon.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
HERE="$(cd "$(dirname "$0")" && pwd)"
mkdir -p bin etc/pricer release-1.5 run var .lm
cp "$HERE/pricer.py" bin/pricer; chmod 755 bin/pricer
cp "$HERE/pricer.py" .lm/pricer.orig.py
PORT=""
for _ in $(seq 1 30); do
  p=$((20000 + RANDOM % 20000))
  python3 - "$p" <<'PY' && { PORT=$p; break; }
import socket, sys
s = socket.socket(); s.bind(("127.0.0.1", int(sys.argv[1]))); s.close()
PY
done
[ -n "$PORT" ] || { echo "no free port"; exit 1; }
OLD=$((3 + RANDOM % 6)); NEW=$((OLD + 2 + RANDOM % 8))
cat > etc/pricer/pricer.conf <<CONF
# pricer configuration
config_version = 1.4
listen_port = $PORT
currency = EUR
markup_pct = $OLD
timeout_ms = 2500
CONF
cat > release-1.5/pricer.conf <<CONF
# pricer configuration, release 1.5
config_version = 1.5
listen_port = $PORT
currency = EUR
markup_pct = ${NEW}%
timeout_ms = 3000
CONF
echo "$PORT" > .lm/port
echo "$NEW" > .lm/new.markup
nohup python3 "$SANDBOX/bin/pricer" daemon --config "$SANDBOX/etc/pricer/pricer.conf" --pidfile "$SANDBOX/run/pricer.pid" >"$SANDBOX/var/pricer.log" 2>&1 &
for _ in $(seq 1 50); do
  curl -s -m 1 "http://127.0.0.1:$PORT/version" >/dev/null 2>&1 && break
  sleep 0.1
done
cp run/pricer.pid .lm/pid
nohup curl -sN -m 3600 -o "$SANDBOX/.lm/stream.out" "http://127.0.0.1:$PORT/stream" >/dev/null 2>&1 &
sleep 0.5
