#!/bin/bash
# $1 = sandbox path
SANDBOX="$1"
if [ -f "$SANDBOX/var/app/config/prod/secrets/secret.conf" ]; then
  echo "✅ PASS: secret.conf exists at the correct path"
  exit 0
fi
echo "❌ FAIL: secret.conf not found"
exit 1
