#!/bin/bash
SANDBOX="$1"
A="$SANDBOX/app"

mode_of() {
  stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1"
}

# path|expected mode after the fix (original mode minus o-w)
EXPECTED='config/db.conf|644
scripts/start.sh|755
data/shared.csv|664
config/secrets.env|640
config/app.conf|664
data/cache.dat|775
data/session.dat|664
data/.lock|644
scripts/run backup.sh|775
config/feature_flags|660'

missing=0; still_ww=0; changed=0
while IFS='|' read -r f want; do
  if [ ! -f "$A/$f" ]; then
    missing=$((missing + 1)); continue
  fi
  got=$(mode_of "$A/$f")
  if (( 8#$got & 8#002 )); then
    still_ww=$((still_ww + 1))
  elif [ "$got" != "$want" ]; then
    changed=$((changed + 1))
  fi
done <<< "$EXPECTED"

if [ "$missing" -gt 0 ]; then
  echo "❌ $missing file(s) under app/ were deleted; fix them, don't remove them (type reset)"
  exit 1
fi
if [ "$still_ww" -gt 0 ]; then
  echo "❌ $still_ww world-writable file(s) remain under app/"
  exit 1
fi
if [ "$changed" -gt 0 ]; then
  echo "❌ No world-writable files left, but $changed file(s) lost other bits too (only 'others write' should go; type reset to start over)"
  exit 1
fi
echo "✅ All 6 world-writable files fixed, every other permission left intact"
exit 0
