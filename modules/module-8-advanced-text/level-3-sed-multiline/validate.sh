#!/bin/bash
SANDBOX="$1"

if grep -A1 '^  # EXTRA CONFIG$' "$SANDBOX/app.conf" | tail -n1 | grep -qx 'include /etc/myapp/extra.conf'; then
  echo "✅ PASS: include line was inserted after the marker"
  exit 0
fi

echo "❌ FAIL: app.conf should include /etc/myapp/extra.conf immediately after # EXTRA CONFIG"
exit 1
