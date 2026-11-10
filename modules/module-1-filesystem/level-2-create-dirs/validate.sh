#!/bin/bash
# $1 = sandbox path
SANDBOX="$1"
cd "$SANDBOX" || exit 1

EXPECTED_README=$'Customer uploads live under data/.\nDo NOT delete or recreate this folder: ticket #4471.'
if [ ! -f data/README ] || [ "$(cat data/README)" != "$EXPECTED_README" ]; then
  echo "❌ data/README was changed or removed; type 'reset' to restore it and try again"
  exit 1
fi

# Brace expansion inside quotes creates literal folders like '{app,nginx}'
odd=$(find . -type d \( -name '*{*' -o -name '*}*' -o -name '*,*' \) | head -n 1)
if [ -n "$odd" ]; then
  echo "❌ found a directory named '${odd#./}': braces inside quotes are not expanded; remove it with rmdir"
  exit 1
fi

missing=0
for d in logs/app logs/nginx data/uploads data/cache/thumbnails tmp/sessions; do
  if [ -e "$d" ] && [ ! -d "$d" ]; then
    echo "❌ $d exists but is a file, not a directory"
    exit 1
  fi
  [ -d "$d" ] || missing=$((missing + 1))
done
if [ "$missing" -gt 0 ]; then
  echo "❌ $missing of the 5 required directories are still missing"
  exit 1
fi
echo "✅ all 5 directories exist and data/README is intact"
exit 0
