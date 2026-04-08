#!/bin/bash
SANDBOX="$1"
FAIL=0
for f in db.conf web.conf logging.conf app.conf; do
  if [ ! -f "$SANDBOX/production/$f" ]; then
    echo "❌ FAIL: Missing production/$f"
    FAIL=1
  fi
done
# staging should not have .conf files anymore
REMAINING=$(find "$SANDBOX/staging" -name "*.conf" 2>/dev/null | wc -l)
if [ "$REMAINING" -gt 0 ]; then
  echo "❌ FAIL: .conf files still in staging/"
  FAIL=1
fi
if [ "$FAIL" -eq 0 ]; then
  echo "✅ PASS: All configs in production/ and staging/ is clean"
  exit 0
fi
exit 1
