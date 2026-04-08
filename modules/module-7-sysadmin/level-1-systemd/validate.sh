#!/bin/bash
SANDBOX="$1"

if [ -f "$SANDBOX/enabled.state" ] && [ -f "$SANDBOX/active.state" ] && grep -qx 'myapp.service' "$SANDBOX/enabled.state" && grep -qx 'myapp.service' "$SANDBOX/active.state"; then
  echo "✅ PASS: myapp.service was enabled and started"
  exit 0
fi

echo "❌ FAIL: myapp.service must be both enabled and started"
exit 1
