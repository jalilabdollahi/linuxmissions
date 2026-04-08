#!/bin/bash
SANDBOX="$1"

if [ ! -f "$SANDBOX/errors.txt" ]; then
  echo "❌ FAIL: errors.txt not found"
  exit 1
fi

EXPECTED=$'Apr 08 13:18:00 app[101]: error failed to load config\nApr 08 13:44:00 app[101]: error database timeout'
ACTUAL="$(tr -d '\r' < "$SANDBOX/errors.txt" | sed '/^$/d')"
if [ "$ACTUAL" = "$EXPECTED" ]; then
  echo "✅ PASS: errors.txt contains the recent error logs"
  exit 0
fi

echo "❌ FAIL: errors.txt should contain only the recent error entries"
exit 1
