#!/bin/bash
SANDBOX="$1"
if [ ! -f "$SANDBOX/token.txt" ]; then
  echo "❌ FAIL: token.txt not found in sandbox root"
  exit 1
fi
if grep -q "AUTH_TOKEN" "$SANDBOX/token.txt"; then
  echo "✅ PASS: token.txt contains the AUTH_TOKEN"
  exit 0
fi
echo "❌ FAIL: token.txt doesn't contain AUTH_TOKEN"
exit 1
