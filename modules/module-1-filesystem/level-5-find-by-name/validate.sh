#!/bin/bash
# $1 = sandbox path
SANDBOX="$1"
cd "$SANDBOX" || exit 1
export LC_ALL=C

if [ ! -f found.txt ]; then
  echo "❌ found.txt does not exist in the sandbox root"
  exit 1
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# What should be listed: every regular .py file, as a path relative to the sandbox
find . -type f -name '*.py' | sed 's|^\./||' | sort -u > "$TMP/expected"

# What the player listed: accept ./x, x, $SANDBOX/x or the fully resolved path
REAL=$(pwd -P)
tr -d '\r' < found.txt |
  sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' |
  awk -v a="${SANDBOX%/}/" -v b="$REAL/" '
    index($0, a) == 1 { $0 = substr($0, length(a) + 1) }
    index($0, b) == 1 { $0 = substr($0, length(b) + 1) }
    { sub(/^\.\//, "") }
    length($0) > 0' | sort -u > "$TMP/found"

missing=$(comm -23 "$TMP/expected" "$TMP/found" | wc -l | tr -d ' ')
extra=$(comm -13 "$TMP/expected" "$TMP/found" | wc -l | tr -d ' ')
total=$(wc -l < "$TMP/expected" | tr -d ' ')

if [ "$extra" -gt 0 ]; then
  # Sort the wrong entries into: not there at all / a directory / some other file
  gone=0; dirs=0
  while IFS= read -r p; do
    if [ -d "$p" ]; then dirs=$((dirs + 1)); elif [ ! -e "$p" ]; then gone=$((gone + 1)); fi
  done < <(comm -13 "$TMP/expected" "$TMP/found")
  if [ "$gone" -gt 0 ]; then
    echo "❌ $gone line(s) in found.txt are not paths that exist (write each file's path from the sandbox root, e.g. ./project-a/...)"
  elif [ "$dirs" -gt 0 ]; then
    echo "❌ found.txt lists $dirs directory(ies); only regular files count, even if the name ends in .py"
  else
    echo "❌ found.txt lists $extra file(s) whose name does not end in .py"
  fi
  exit 1
fi
if [ "$missing" -gt 0 ]; then
  echo "❌ found.txt is missing $missing of the $total .py files"
  exit 1
fi
echo "✅ found.txt lists all $total Python files and nothing else"
exit 0
