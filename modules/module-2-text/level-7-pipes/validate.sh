#!/bin/bash
SANDBOX="$1"
if [ ! -f "$SANDBOX/post_ips.txt" ]; then
  echo "❌ FAIL: post_ips.txt not found"; exit 1
fi
# Should contain 3 IPs (all 3 sent POSTs), highest count first
LINES=$(wc -l < "$SANDBOX/post_ips.txt")
if [ "$LINES" -lt 3 ]; then
  echo "❌ FAIL: post_ips.txt has $LINES lines, expected 3 IPs"; exit 1
fi
# Check no GET lines slipped in
if grep -q "GET" "$SANDBOX/post_ips.txt"; then
  echo "❌ FAIL: post_ips.txt contains GET entries"; exit 1
fi
# Top IP should have count 4 (10.0.1.2)
FIRST_COUNT=$(head -1 "$SANDBOX/post_ips.txt" | awk '{print $1}')
if [ "$FIRST_COUNT" = "4" ]; then
  echo "✅ PASS: post_ips.txt correctly ranked (10.0.1.2 has 4 POSTs on top)"
  exit 0
fi
echo "❌ FAIL: Top count should be 4 (10.0.1.2), got: $FIRST_COUNT"
exit 1
