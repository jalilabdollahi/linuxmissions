#!/bin/bash
SANDBOX="$1"

RULE_FILE="$SANDBOX/sudoers.d/devuser"
EXPECTED='devuser ALL=(ALL) NOPASSWD: /usr/bin/systemctl'

if [ ! -f "$RULE_FILE" ]; then
  echo "❌ FAIL: sudoers.d/devuser not found"
  exit 1
fi

if grep -Fxq "$EXPECTED" "$RULE_FILE"; then
  echo "✅ PASS: sudoers rule grants the expected command without a password"
  exit 0
fi

echo "❌ FAIL: sudoers.d/devuser should contain: $EXPECTED"
exit 1
