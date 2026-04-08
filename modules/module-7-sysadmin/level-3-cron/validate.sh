#!/bin/bash
SANDBOX="$1"

if [ ! -f "$SANDBOX/crontab.txt" ]; then
  echo "❌ FAIL: crontab.txt not found"
  exit 1
fi

EXPECTED="0 3 * * * $SANDBOX/cleanup.sh"
if grep -Fxq "$EXPECTED" "$SANDBOX/crontab.txt"; then
  echo "✅ PASS: crontab.txt schedules cleanup.sh for 3am daily"
  exit 0
fi

echo "❌ FAIL: crontab.txt should contain: $EXPECTED"
exit 1
