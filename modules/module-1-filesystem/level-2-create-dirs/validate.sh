#!/bin/bash
SANDBOX="$1"
FAIL=0
for d in logs/app logs/nginx data/uploads data/cache; do
  if [ ! -d "$SANDBOX/$d" ]; then
    echo "❌ FAIL: Missing directory: $d"
    FAIL=1
  fi
done
if [ "$FAIL" -eq 0 ]; then
  echo "✅ PASS: All required directories exist"
  exit 0
fi
exit 1
