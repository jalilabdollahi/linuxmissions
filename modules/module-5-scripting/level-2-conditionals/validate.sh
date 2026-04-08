#!/bin/bash
SANDBOX="$1"

if [ ! -f "$SANDBOX/check_file.sh" ]; then
  echo "❌ FAIL: check_file.sh not found"
  exit 1
fi

EXISTS_OUTPUT="$(bash "$SANDBOX/check_file.sh" "$SANDBOX/present.txt" 2>/dev/null | tr -d '\r')"
MISSING_OUTPUT="$(bash "$SANDBOX/check_file.sh" "$SANDBOX/missing.txt" 2>/dev/null | tr -d '\r')"

if [ "$EXISTS_OUTPUT" = "EXISTS" ] && [ "$MISSING_OUTPUT" = "MISSING" ]; then
  echo "✅ PASS: check_file.sh handles both cases"
  exit 0
fi

echo "❌ FAIL: Expected EXISTS/MISSING but got '$EXISTS_OUTPUT' and '$MISSING_OUTPUT'"
exit 1
