#!/bin/bash
SANDBOX="$1"
PERMS=$(stat -c "%a" "$SANDBOX/shared" 2>/dev/null)
if [ "$PERMS" = "1777" ] || [ "$PERMS" = "1755" ] || [ "$PERMS" = "1775" ]; then
  echo "✅ PASS: Sticky bit is set on shared/ (permissions: $PERMS)"
  exit 0
fi
# Check symbolic
if ls -ld "$SANDBOX/shared" | grep -q "T\|t"; then
  echo "✅ PASS: Sticky bit is set on shared/"
  exit 0
fi
echo "❌ FAIL: Sticky bit not set on shared/ (current: $PERMS)"
exit 1
