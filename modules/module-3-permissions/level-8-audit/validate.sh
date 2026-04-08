#!/bin/bash
SANDBOX="$1"
REMAINING=$(find "$SANDBOX/app" -perm /o+w -type f 2>/dev/null | wc -l)
if [ "$REMAINING" -eq 0 ]; then
  echo "✅ PASS: No world-writable files remain"
  exit 0
fi
echo "❌ FAIL: $REMAINING world-writable file(s) still exist:"
find "$SANDBOX/app" -perm /o+w -type f 2>/dev/null
exit 1
