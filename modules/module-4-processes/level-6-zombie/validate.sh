#!/bin/bash
SANDBOX="$1"

if [ ! -s "$SANDBOX/zombies.txt" ]; then
  echo "❌ FAIL: zombies.txt not found or empty"
  exit 1
fi

if [ ! -f "$SANDBOX/parent.pid" ]; then
  echo "❌ FAIL: parent.pid not found"
  exit 1
fi

PARENT_PID="$(cat "$SANDBOX/parent.pid")"

if kill -0 "$PARENT_PID" 2>/dev/null; then
  echo "❌ FAIL: Parent process $PARENT_PID is still running"
  exit 1
fi

if ps -o stat= -p "$PARENT_PID" 2>/dev/null | grep -q "Z"; then
  echo "❌ FAIL: Parent process became a zombie"
  exit 1
fi

echo "✅ PASS: Zombies documented and parent process stopped"
exit 0
