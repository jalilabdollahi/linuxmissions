#!/bin/bash
SANDBOX="$1"

if [ ! -f "$SANDBOX/reload.log" ]; then
  echo "❌ FAIL: reload.log not found"
  exit 1
fi

if grep -q "reloaded" "$SANDBOX/reload.log"; then
  echo "✅ PASS: listener.sh received SIGHUP and reloaded"
  exit 0
fi

echo "❌ FAIL: reload.log does not contain the reload marker"
exit 1
