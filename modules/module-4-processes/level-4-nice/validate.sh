#!/bin/bash
SANDBOX="$1"
PID=$(cat "$SANDBOX/.heavy.pid" 2>/dev/null)

STAT=$(ps -o stat= -p "$PID" 2>/dev/null)
if [ -z "$PID" ] || [ -z "$STAT" ] || [[ "$STAT" == Z* ]]; then
  echo "❌ The original heavy.sh job is gone; it had to keep running (type reset to start it again)"
  exit 1
fi

NI=$(ps -o ni= -p "$PID" 2>/dev/null | tr -d '[:space:]')
if [ "$NI" = "15" ]; then
  echo "✅ heavy.sh (PID $PID) keeps running, now at niceness 15"
  exit 0
fi
echo "❌ heavy.sh (PID $PID) is running at niceness $NI, expected 15"
exit 1
