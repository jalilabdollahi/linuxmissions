#!/bin/bash
SANDBOX="$1"
if [ ! -f "$SANDBOX/found.txt" ]; then
  echo "❌ FAIL: found.txt does not exist in sandbox root"
  exit 1
fi
COUNT=$(grep -c "\.py$" "$SANDBOX/found.txt" 2>/dev/null || echo 0)
if [ "$COUNT" -ge 5 ]; then
  echo "✅ PASS: found.txt contains $COUNT Python file paths"
  exit 0
fi
echo "❌ FAIL: found.txt has $COUNT .py entries, expected at least 5"
exit 1
