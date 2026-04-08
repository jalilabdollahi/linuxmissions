#!/bin/bash
SANDBOX="$1"
if [ ! -f "$SANDBOX/leak.txt" ]; then
  echo "❌ FAIL: leak.txt not found"
  exit 1
fi
if grep -q "database.conf" "$SANDBOX/leak.txt"; then
  echo "✅ PASS: leak.txt correctly identifies database.conf"
  exit 0
fi
echo "❌ FAIL: leak.txt does not reference the correct file (database.conf)"
exit 1
