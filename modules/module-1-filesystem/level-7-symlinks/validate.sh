#!/bin/bash
SANDBOX="$1"
LINK="$SANDBOX/etc/myapp/active.conf"
if [ ! -L "$LINK" ]; then
  echo "❌ FAIL: active.conf is not a symlink"
  exit 1
fi
TARGET=$(readlink "$LINK")
# Accept both absolute and relative paths pointing to v2/config.conf
if echo "$TARGET" | grep -q "v2/config.conf"; then
  echo "✅ PASS: active.conf → v2/config.conf"
  exit 0
fi
echo "❌ FAIL: symlink points to '$TARGET', expected v2/config.conf"
exit 1
