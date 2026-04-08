#!/bin/bash
SANDBOX="$1"

if [ ! -f "$SANDBOX/.env" ]; then
  echo "❌ FAIL: .env not found"
  exit 1
fi

OUTPUT="$(bash -c 'set -a; source "$1/.env"; set +a; "$1/app.sh"' _ "$SANDBOX" 2>/dev/null | tr -d '\r')"
if [ "$OUTPUT" = "app ready" ]; then
  echo "✅ PASS: .env now provides the required variables"
  exit 0
fi

echo "❌ FAIL: sourcing .env should allow app.sh to print 'app ready'"
exit 1
