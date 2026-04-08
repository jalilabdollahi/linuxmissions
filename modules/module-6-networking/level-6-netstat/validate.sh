#!/bin/bash
SANDBOX="$1"

if [ ! -f "$SANDBOX/unique_ips.txt" ]; then
  echo "❌ FAIL: unique_ips.txt not found"
  exit 1
fi

COUNT="$(tr -d '\r[:space:]' < "$SANDBOX/unique_ips.txt")"
if [ "$COUNT" = "3" ]; then
  echo "✅ PASS: unique_ips.txt contains the correct unique remote IP count"
  exit 0
fi

echo "❌ FAIL: Expected 3 unique remote IPs"
exit 1
