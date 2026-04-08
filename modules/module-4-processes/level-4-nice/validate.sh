#!/bin/bash
SANDBOX="$1"

if [ ! -f "$SANDBOX/pid.txt" ]; then
  echo "❌ FAIL: pid.txt not found"
  exit 1
fi

PID="$(cat "$SANDBOX/pid.txt")"
if ! [[ "$PID" =~ ^[0-9]+$ ]]; then
  echo "❌ FAIL: pid.txt does not contain a valid PID"
  exit 1
fi

if ! kill -0 "$PID" 2>/dev/null; then
  echo "❌ FAIL: Process $PID is not running"
  exit 1
fi

NI="$(ps -o ni= -p "$PID" 2>/dev/null | tr -d '[:space:]')"
if [ -z "$NI" ]; then
  echo "❌ FAIL: Could not read niceness for PID $PID"
  exit 1
fi

if [ "$NI" -ge 10 ]; then
  kill "$PID" 2>/dev/null || true
  echo "✅ PASS: Process $PID is running with niceness $NI"
  exit 0
fi

echo "❌ FAIL: Process $PID niceness is $NI, expected at least 10"
exit 1
