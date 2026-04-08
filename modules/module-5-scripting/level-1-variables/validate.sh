#!/bin/bash
SANDBOX="$1"

if [ ! -f "$SANDBOX/greet.sh" ]; then
  echo "❌ FAIL: greet.sh not found"
  exit 1
fi

OUTPUT="$(bash "$SANDBOX/greet.sh" World 2>/dev/null | tr -d '\r')"
if [ "$OUTPUT" = "Hello, World!" ]; then
  echo "✅ PASS: greet.sh uses the first argument correctly"
  exit 0
fi

echo "❌ FAIL: Expected 'Hello, World!' but got '$OUTPUT'"
exit 1
