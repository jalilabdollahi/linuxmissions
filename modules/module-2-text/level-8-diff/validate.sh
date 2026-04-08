#!/bin/bash
SANDBOX="$1"
if [ ! -f "$SANDBOX/changes.diff" ]; then
  echo "❌ FAIL: changes.diff not found"; exit 1
fi
# Diff output should be non-empty and contain some diff markers
if grep -qE "^[<>+-]" "$SANDBOX/changes.diff"; then
  echo "✅ PASS: changes.diff contains valid diff output"
  exit 0
fi
echo "❌ FAIL: changes.diff appears empty or has no diff markers"
exit 1
