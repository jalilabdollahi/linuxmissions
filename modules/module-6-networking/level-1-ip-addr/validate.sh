#!/bin/bash
SANDBOX="$1"

if [ ! -f "$SANDBOX/interfaces.txt" ]; then
  echo "❌ FAIL: interfaces.txt not found"
  exit 1
fi

EXPECTED=$'lo 127.0.0.1\neth0 192.168.56.20\nwlan0 10.0.0.44'
ACTUAL="$(tr -d '\r' < "$SANDBOX/interfaces.txt" | sed '/^$/d')"
if [ "$ACTUAL" = "$EXPECTED" ]; then
  echo "✅ PASS: interfaces.txt lists the expected interfaces and IPs"
  exit 0
fi

echo "❌ FAIL: interfaces.txt does not match the expected interface summary"
exit 1
