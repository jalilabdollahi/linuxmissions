#!/bin/bash
SANDBOX="$1"
CURRENT_USER=$(whoami)
FAIL=0
for f in "$SANDBOX/config/"*.conf; do
  OWNER=$(stat -c "%U" "$f" 2>/dev/null)
  if [ "$OWNER" = "$CURRENT_USER" ]; then
    echo "✅ $(basename $f) owned by $CURRENT_USER"
  else
    echo "❌ $(basename $f) owned by $OWNER (expected $CURRENT_USER)"
    FAIL=1
  fi
done
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
