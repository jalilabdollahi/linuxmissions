#!/bin/bash
SANDBOX="$1"

if [ ! -f "$SANDBOX/listening.txt" ]; then
  echo "❌ FAIL: listening.txt not found"
  exit 1
fi

EXPECTED=$'22\n80\n5432\n8080'
ACTUAL="$(sort -n "$SANDBOX/listening.txt" | tr -d '\r' | sed '/^$/d')"
if [ "$ACTUAL" = "$EXPECTED" ]; then
  echo "✅ PASS: listening.txt lists the listening TCP ports"
  exit 0
fi

echo "❌ FAIL: listening.txt should contain 22, 80, 5432, and 8080"
exit 1
