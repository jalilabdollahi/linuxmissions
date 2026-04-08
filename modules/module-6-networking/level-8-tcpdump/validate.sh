#!/bin/bash
SANDBOX="$1"

if [ ! -f "$SANDBOX/protocol.txt" ]; then
  echo "❌ FAIL: protocol.txt not found"
  exit 1
fi

PROTO="$(tr '[:upper:]' '[:lower:]' < "$SANDBOX/protocol.txt" | tr -d '\r[:space:]')"
if [ "$PROTO" = "dns" ]; then
  echo "✅ PASS: protocol.txt identifies the capture protocol"
  exit 0
fi

echo "❌ FAIL: The capture shows DNS traffic"
exit 1
