#!/bin/bash
SANDBOX="$1"
if [ ! -f "$SANDBOX/biggest.txt" ]; then
  echo "❌ FAIL: biggest.txt not found"
  exit 1
fi
if grep -q "hugefile.dat" "$SANDBOX/biggest.txt"; then
  echo "✅ PASS: biggest.txt correctly identifies hugefile.dat"
  exit 0
fi
echo "❌ FAIL: biggest.txt doesn't mention hugefile.dat"
exit 1
