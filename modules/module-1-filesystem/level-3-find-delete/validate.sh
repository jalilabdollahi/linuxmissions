#!/bin/bash
SANDBOX="$1"
REMAINING=$(find "$SANDBOX" -name "*.tmp" 2>/dev/null | wc -l)
if [ "$REMAINING" -eq 0 ]; then
  # Also check keeper files survived
  if [ -f "$SANDBOX/a/important.log" ] && [ -f "$SANDBOX/b/c/config.yaml" ]; then
    echo "✅ PASS: All .tmp files removed and other files intact"
    exit 0
  fi
  echo "❌ FAIL: .tmp files gone but keeper files were also deleted!"
  exit 1
fi
echo "❌ FAIL: $REMAINING .tmp file(s) still exist"
exit 1
