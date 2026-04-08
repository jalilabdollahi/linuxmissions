#!/bin/bash
SANDBOX="$1"

if [ ! -f "$SANDBOX/safe_copy.sh" ]; then
  echo "❌ FAIL: safe_copy.sh not found"
  exit 1
fi

CONTENT="$(cat "$SANDBOX/safe_copy.sh")"
if ! printf '%s' "$CONTENT" | grep -q 'set -euo pipefail'; then
  echo "❌ FAIL: safe_copy.sh should enable strict mode with set -euo pipefail"
  exit 1
fi

MISSING_OUTPUT="$(cd "$SANDBOX" && bash ./safe_copy.sh 2>&1)"
if ! printf '%s' "$MISSING_OUTPUT" | grep -q '^SOURCE_FILE is required$'; then
  echo "❌ FAIL: Missing input should print 'SOURCE_FILE is required'"
  exit 1
fi

SUCCESS_OUTPUT="$(cd "$SANDBOX" && bash ./safe_copy.sh "$SANDBOX/source.txt" 2>/dev/null)"
if [ -f "$SANDBOX/copied.txt" ] && grep -qx 'payload' "$SANDBOX/copied.txt" && printf '%s' "$SUCCESS_OUTPUT" | grep -q 'copy complete'; then
  echo "✅ PASS: safe_copy.sh now fails clearly and succeeds safely"
  exit 0
fi

echo "❌ FAIL: safe_copy.sh did not copy the file correctly"
exit 1
