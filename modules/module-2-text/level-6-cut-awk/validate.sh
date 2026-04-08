#!/bin/bash
SANDBOX="$1"
if [ ! -f "$SANDBOX/extract.csv" ]; then
  echo "❌ FAIL: extract.csv not found"; exit 1
fi
# Should have 5 lines
LINES=$(wc -l < "$SANDBOX/extract.csv")
if [ "$LINES" -lt 5 ]; then
  echo "❌ FAIL: extract.csv has $LINES lines, expected 5"; exit 1
fi
# First line should be alice,alice@example.com
FIRST=$(head -1 "$SANDBOX/extract.csv")
if [ "$FIRST" = "alice,alice@example.com" ]; then
  echo "✅ PASS: extract.csv correctly contains username and email"
  exit 0
fi
echo "❌ FAIL: First line should be 'alice,alice@example.com', got: $FIRST"
exit 1
