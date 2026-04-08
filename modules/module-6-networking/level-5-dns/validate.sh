#!/bin/bash
SANDBOX="$1"

if [ ! -f "$SANDBOX/resolved.txt" ]; then
  echo "❌ FAIL: resolved.txt not found"
  exit 1
fi

EXPECTED=$'app.internal 10.10.0.5\ndb.internal 10.10.0.8\ncache.internal 10.10.0.9'
ACTUAL="$(tr -d '\r' < "$SANDBOX/resolved.txt" | sed '/^$/d')"
if [ "$ACTUAL" = "$EXPECTED" ]; then
  echo "✅ PASS: resolved.txt contains all hostname/IP pairs"
  exit 0
fi

echo "❌ FAIL: resolved.txt does not contain the expected DNS results"
exit 1
