#!/bin/bash
SANDBOX="$1"

if [ ! -f "$SANDBOX/result.txt" ]; then
  echo "❌ FAIL: result.txt not found yet"
  exit 1
fi

if grep -qx "done" "$SANDBOX/result.txt"; then
  echo "✅ PASS: Background job finished and wrote result.txt"
  exit 0
fi

echo "❌ FAIL: result.txt exists but does not contain the expected output"
exit 1
