#!/bin/bash
SANDBOX="$1"
FAIL=0
if [ ! -f "$SANDBOX/first5.txt" ]; then
  echo "❌ FAIL: first5.txt not found"; FAIL=1
else
  COUNT=$(wc -l < "$SANDBOX/first5.txt")
  if [ "$COUNT" -eq 5 ] && grep -q "Service started" "$SANDBOX/first5.txt"; then
    echo "✅ first5.txt correct ($COUNT lines, starts with 'Service started')"
  else
    echo "❌ FAIL: first5.txt has $COUNT lines or wrong content"; FAIL=1
  fi
fi
if [ ! -f "$SANDBOX/last5.txt" ]; then
  echo "❌ FAIL: last5.txt not found"; FAIL=1
else
  COUNT=$(wc -l < "$SANDBOX/last5.txt")
  if [ "$COUNT" -eq 5 ] && grep -q "Shutting down" "$SANDBOX/last5.txt"; then
    echo "✅ last5.txt correct ($COUNT lines, ends with 'Shutting down')"
  else
    echo "❌ FAIL: last5.txt has $COUNT lines or wrong content"; FAIL=1
  fi
fi
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
