#!/bin/bash
SANDBOX="$1"

if [ ! -f "$SANDBOX/ips.txt" ]; then
  echo "❌ FAIL: ips.txt not found"
  exit 1
fi

EXPECTED=$'10.1.1.5\n172.16.0.44\n192.168.1.200'
ACTUAL="$(tr -d '\r' < "$SANDBOX/ips.txt" | sed '/^$/d')"
if [ "$ACTUAL" = "$EXPECTED" ]; then
  echo "✅ PASS: ips.txt contains the extracted IPv4 addresses"
  exit 0
fi

echo "❌ FAIL: ips.txt does not contain the expected IP addresses"
exit 1
