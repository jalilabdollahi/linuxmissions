#!/bin/bash
SANDBOX="$1"

if [ ! -f "$SANDBOX/reachable.txt" ]; then
  echo "❌ FAIL: reachable.txt not found"
  exit 1
fi

EXPECTED=$'web-1\ncache-1'
ACTUAL="$(tr -d '\r' < "$SANDBOX/reachable.txt" | sed '/^$/d')"
if [ "$ACTUAL" = "$EXPECTED" ]; then
  echo "✅ PASS: reachable.txt lists the reachable hosts"
  exit 0
fi

echo "❌ FAIL: reachable.txt should contain only web-1 and cache-1"
exit 1
