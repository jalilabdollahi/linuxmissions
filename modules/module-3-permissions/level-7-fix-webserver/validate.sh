#!/bin/bash
SANDBOX="$1"
FAIL=0

# Check dirs are 755
while IFS= read -r -d '' d; do
  PERM=$(stat -c "%a" "$d")
  if [ "$PERM" != "755" ]; then
    echo "❌ Directory $(basename $d): $PERM (expected 755)"
    FAIL=1
  fi
done < <(find "$SANDBOX/webroot" -type d -print0)

# Check files are 644
while IFS= read -r -d '' f; do
  PERM=$(stat -c "%a" "$f")
  if [ "$PERM" != "644" ]; then
    echo "❌ File $(basename $f): $PERM (expected 644)"
    FAIL=1
  fi
done < <(find "$SANDBOX/webroot" -type f -print0)

if [ "$FAIL" -eq 0 ]; then
  echo "✅ PASS: All web files are 644 and directories are 755"
  exit 0
fi
exit 1
