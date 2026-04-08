#!/bin/bash
SANDBOX="$1"

if [ ! -f "$SANDBOX/blocked_port.txt" ]; then
  echo "❌ FAIL: blocked_port.txt not found"
  exit 1
fi

PORT="$(tr -d '\r[:space:]' < "$SANDBOX/blocked_port.txt")"
if [ "$PORT" = "3306" ]; then
  echo "✅ PASS: blocked_port.txt identifies the denied port"
  exit 0
fi

echo "❌ FAIL: The blocked port should be 3306"
exit 1
