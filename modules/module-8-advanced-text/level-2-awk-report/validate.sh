#!/bin/bash
SANDBOX="$1"

if [ ! -f "$SANDBOX/totals.txt" ]; then
  echo "❌ FAIL: totals.txt not found"
  exit 1
fi

EXPECTED=$'travel 165\nsoftware 100\nfood 40'
ACTUAL="$(tr -d '\r' < "$SANDBOX/totals.txt" | sed '/^$/d')"
if [ "$ACTUAL" = "$EXPECTED" ]; then
  echo "✅ PASS: totals.txt contains the sorted category totals"
  exit 0
fi

echo "❌ FAIL: totals.txt should list travel 165, software 100, and food 40"
exit 1
