#!/bin/bash
SB="$1"; cd "$SB" || exit 1
if [ ! -d restored ]; then echo "❌ restored/ does not exist yet"; exit 1; fi
( cd restored && { find . -mindepth 1 -type d | sort | sed 's/^/d /'; find . -type f | sort | while read -r f; do echo "f $(sha256sum < "$f" | cut -c1-64) $f"; done; } ) > .lm/got.txt
if cmp -s .lm/got.txt .lm/expected.txt; then
  echo "✅ restored/ is exactly the share as it was on Tuesday 18:00"; exit 0
fi
miss=$(grep -Fxvf .lm/got.txt .lm/expected.txt | wc -l); extra=$(grep -Fxvf .lm/expected.txt .lm/got.txt | wc -l)
if [ -e restored/READ_ME_NOW.txt ] || [ -n "$(find restored -name '*.locked' | head -1)" ]; then
  echo "❌ restored/ contains Wednesday's ransomware files"; exit 1; fi
echo "❌ restored/ is not Tuesday 18:00 yet: $miss expected entr(ies) missing or different, $extra entr(ies) that should not be there (deleted files, old versions or truncated data)"
exit 1
