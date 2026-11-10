#!/bin/bash
# The process listening on 127.0.0.1:PORT must be the 2.0 release (by its
# command line); the old 1.9 instance must be gone; the other two services
# must still be alive.
SANDBOX="$1"
. "$SANDBOX/.srv/state"

alive() {  # alive PID PATTERN: process PID runs and its command line contains PATTERN
  [ -r "/proc/$1/cmdline" ] && tr '\0' ' ' < "/proc/$1/cmdline" | grep -q -- "$2"
}

if ! alive "$RELAY" audit-relay; then
  echo "❌ audit-relay is not running anymore; it was not in the way (type reset to start over)"
  exit 1
fi
if ! alive "$METRICS" metrics-agent; then
  echo "❌ metrics-agent is not running anymore; it was not in the way (type reset to start over)"
  exit 1
fi

line=$(ss -Hltnp "( sport = :$PORT )" 2>/dev/null | grep '127\.0\.0\.1:')
pid=$(echo "$line" | grep -o 'pid=[0-9]*' | head -n 1 | cut -d= -f2)
if [ -z "$line" ]; then
  echo "❌ nothing listens on 127.0.0.1:$PORT now; start the new release"
  exit 1
fi
if [ -n "$pid" ] && alive "$pid" "releases/ledger-api-2.0"; then
  if alive "$OLD" ledger-api-1.9; then
    echo "❌ the old 1.9 instance is still running"
    exit 1
  fi
  echo "✅ ledger-api 2.0 (PID $pid) listens on 127.0.0.1:$PORT; the old instance is gone, the other services still run"
  exit 0
fi
echo "❌ 127.0.0.1:$PORT is still held by a process that is not ledger-api 2.0"
exit 1
