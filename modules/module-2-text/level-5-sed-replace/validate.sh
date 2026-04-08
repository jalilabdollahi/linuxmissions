#!/bin/bash
SANDBOX="$1"
if [ ! -f "$SANDBOX/config.prod.conf" ]; then
  echo "❌ FAIL: config.prod.conf not found"; exit 1
fi
STAGING_COUNT=$(grep -c "staging.internal" "$SANDBOX/config.prod.conf" 2>/dev/null || echo 0)
PROD_COUNT=$(grep -c "prod.internal" "$SANDBOX/config.prod.conf" 2>/dev/null || echo 0)
if [ "$STAGING_COUNT" -gt 0 ]; then
  echo "❌ FAIL: config.prod.conf still contains 'staging.internal' ($STAGING_COUNT occurrences)"; exit 1
fi
if [ "$PROD_COUNT" -ge 5 ]; then
  echo "✅ PASS: All references updated to prod.internal ($PROD_COUNT occurrences)"
  exit 0
fi
echo "❌ FAIL: Only $PROD_COUNT prod.internal references found, expected 5"
exit 1
