#!/bin/bash
SANDBOX="$1"
# Check if the process is still running
if [ -f "$SANDBOX/loop.pid" ]; then
  PID=$(cat "$SANDBOX/loop.pid")
  if kill -0 "$PID" 2>/dev/null; then
    echo "❌ FAIL: Process $PID is still running"
    exit 1
  fi
fi
# Double-check by process name
if pgrep -f "sleep_loop.sh" > /dev/null 2>&1; then
  echo "❌ FAIL: sleep_loop.sh process is still running"
  exit 1
fi
echo "✅ PASS: sleep_loop.sh has been killed"
exit 0
