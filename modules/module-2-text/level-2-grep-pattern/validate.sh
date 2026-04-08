#!/bin/bash
SANDBOX="$1"
if [ ! -f "$SANDBOX/errors.txt" ]; then
  echo "❌ FAIL: errors.txt not found"; exit 1
fi
COUNT=$(wc -l < "$SANDBOX/errors.txt")
if [ "$COUNT" -lt 4 ]; then
  echo "❌ FAIL: errors.txt has $COUNT lines, expected at least 4 (3 ERROR + 1 FATAL)"; exit 1
fi
if grep -q "INFO" "$SANDBOX/errors.txt"; then
  echo "❌ FAIL: errors.txt contains INFO lines — only ERROR/FATAL should be included"; exit 1
fi
echo "✅ PASS: errors.txt has $COUNT error/fatal lines and no INFO lines"
exit 0
