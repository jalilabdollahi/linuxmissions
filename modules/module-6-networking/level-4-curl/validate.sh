#!/bin/bash
SANDBOX="$1"

if [ ! -f "$SANDBOX/status.txt" ]; then
  echo "❌ FAIL: status.txt not found"
  exit 1
fi

STATUS="$(tr -d '\r' < "$SANDBOX/status.txt" | sed '/^$/d')"
if [ "$STATUS" = "healthy" ]; then
  echo "✅ PASS: status.txt contains the API status"
  exit 0
fi

echo "❌ FAIL: Expected status.txt to contain 'healthy'"
exit 1
