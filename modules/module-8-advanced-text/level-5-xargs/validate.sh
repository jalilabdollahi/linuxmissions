#!/bin/bash
SANDBOX="$1"

if [ ! -f "$SANDBOX/match.txt" ]; then
  echo "❌ FAIL: match.txt not found"
  exit 1
fi

MATCH="$(tr -d '\r[:space:]' < "$SANDBOX/match.txt")"
if [ "$MATCH" = "file-37.txt" ]; then
  echo "✅ PASS: match.txt identifies the correct file"
  exit 0
fi

echo "❌ FAIL: The matching file is file-37.txt"
exit 1
