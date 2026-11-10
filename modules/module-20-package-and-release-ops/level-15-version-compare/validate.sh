#!/bin/bash
# sorted.txt must be a permutation of versions.txt and strictly ascending under dpkg.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
export LC_ALL=C
F=sorted.txt
if [ ! -s "$F" ]; then
  echo "❌ sorted.txt does not exist yet (or is empty)"
  exit 1
fi
total=$(wc -l < versions.txt)
have=$(wc -l < "$F")
if [ "$have" -ne "$total" ]; then
  echo "❌ sorted.txt has $have lines, versions.txt has $total"
  exit 1
fi
if ! diff -q <(sort versions.txt) <(sort "$F") >/dev/null; then
  echo "❌ sorted.txt does not contain exactly the versions of versions.txt (typo, change or missing line)"
  exit 1
fi
prev=""; n=0
while IFS= read -r v; do
  n=$((n + 1))
  if [ -n "$prev" ] && ! dpkg --compare-versions "$prev" lt "$v"; then
    echo "❌ lines $((n - 1)) and $n are in the wrong order for dpkg (the order must go from oldest to newest)"
    exit 1
  fi
  prev="$v"
done < "$F"
echo "✅ sorted.txt follows dpkg's version order"
