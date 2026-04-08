#!/bin/bash
SANDBOX="$1"
if [ ! -f "$SANDBOX/top_ips.txt" ]; then
  echo "❌ FAIL: top_ips.txt not found"; exit 1
fi
# First line should have the highest count IP (192.168.1.10 with 5 hits or 10.0.0.5 with 4)
FIRST_IP=$(head -1 "$SANDBOX/top_ips.txt" | awk '{print $NF}')
if [ "$FIRST_IP" = "192.168.1.10" ]; then
  echo "✅ PASS: top_ips.txt correctly ranks 192.168.1.10 first (5 requests)"
  exit 0
fi
echo "❌ FAIL: First IP should be 192.168.1.10 (5 requests), got: $FIRST_IP"
exit 1
