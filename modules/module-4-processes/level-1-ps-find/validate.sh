#!/bin/bash
SANDBOX="$1"
if [ ! -f "$SANDBOX/top_procs.txt" ]; then
  echo "❌ FAIL: top_procs.txt not found"; exit 1
fi
LINES=$(wc -l < "$SANDBOX/top_procs.txt")
if [ "$LINES" -ge 5 ]; then
  echo "✅ PASS: top_procs.txt has $LINES lines of process info"
  exit 0
fi
echo "❌ FAIL: top_procs.txt has $LINES lines, expected at least 5"
exit 1
