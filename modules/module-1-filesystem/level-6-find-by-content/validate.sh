#!/bin/bash
# $1 = sandbox path
SANDBOX="$1"
cd "$SANDBOX" || exit 1
export LC_ALL=C
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

if [ ! -f leak.txt ]; then
  echo "❌ leak.txt does not exist in the sandbox root"
  exit 1
fi

# Every file (hidden ones too) containing password=, except leak.txt itself
grep -rlF 'password=' . 2>/dev/null | sed 's|^\./||' | grep -vx 'leak.txt' | sort -u > "$TMP/expected"

# The player's list, made relative to the sandbox
REAL=$(pwd -P)
tr -d '\r' < leak.txt |
  sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' |
  awk -v a="${SANDBOX%/}/" -v b="$REAL/" '
    index($0, a) == 1 { $0 = substr($0, length(a) + 1) }
    index($0, b) == 1 { $0 = substr($0, length(b) + 1) }
    { sub(/^\.\//, "") }
    length($0) > 0' | sort -u > "$TMP/found"

if grep -q ':' "$TMP/found" && ! grep -q ':' "$TMP/expected"; then
  echo "❌ leak.txt contains matching lines; it should contain only file paths"
  exit 1
fi
missing=$(comm -23 "$TMP/expected" "$TMP/found" | wc -l | tr -d ' ')
extra=$(comm -13 "$TMP/expected" "$TMP/found" | wc -l | tr -d ' ')
total=$(wc -l < "$TMP/expected" | tr -d ' ')
if [ "$extra" -gt 0 ]; then
  echo "❌ leak.txt lists $extra path(s) that do not contain password="
  exit 1
fi
if [ "$missing" -gt 0 ]; then
  echo "❌ leak.txt is missing $missing of the $total leaking files"
  exit 1
fi
echo "✅ leak.txt lists all $total files that contain password="
exit 0
