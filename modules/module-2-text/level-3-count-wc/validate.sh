#!/bin/bash
SANDBOX="$1"
if [ ! -f "$SANDBOX/report.txt" ]; then
  echo "❌ FAIL: report.txt not found"; exit 1
fi
# Check that report.txt has at least 3 lines
LINES=$(wc -l < "$SANDBOX/report.txt")
if [ "$LINES" -lt 3 ]; then
  echo "❌ FAIL: report.txt has $LINES lines, needs at least 3"; exit 1
fi
# Check for 10 total requests
if grep -q "10" "$SANDBOX/report.txt"; then
  echo "✅ report.txt looks correct (contains '10' for total requests)"
  exit 0
fi
echo "❌ FAIL: report.txt should contain total requests (10), unique IPs (4), and total bytes (6208)"
exit 1
