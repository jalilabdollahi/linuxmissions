#!/bin/bash
SANDBOX="$1"
FILE="$SANDBOX/myapp.logrotate"

if [ ! -f "$FILE" ]; then
  echo "❌ FAIL: myapp.logrotate not found"
  exit 1
fi

if grep -q '^/var/log/myapp/\*\.log[[:space:]]*{' "$FILE" && grep -q '^[[:space:]]*daily$' "$FILE" && grep -q '^[[:space:]]*rotate[[:space:]]\+7$' "$FILE" && grep -q '^[[:space:]]*compress$' "$FILE"; then
  echo "✅ PASS: logrotate config contains the required directives"
  exit 0
fi

echo "❌ FAIL: myapp.logrotate must target /var/log/myapp/*.log and include daily, rotate 7, and compress"
exit 1
