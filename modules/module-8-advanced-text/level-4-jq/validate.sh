#!/bin/bash
SANDBOX="$1"

if [ ! -f "$SANDBOX/report.txt" ]; then
  echo "❌ FAIL: report.txt not found"
  exit 1
fi

EXPECTED=$'owner=ops@example.com\nactive=api,worker'
ACTUAL="$(tr -d '\r' < "$SANDBOX/report.txt" | sed '/^$/d')"
if [ "$ACTUAL" = "$EXPECTED" ]; then
  echo "✅ PASS: report.txt contains the extracted JSON data"
  exit 0
fi

echo "❌ FAIL: report.txt should contain owner=ops@example.com and active=api,worker"
exit 1
