#!/bin/bash
SANDBOX="$1"
Q="$SANDBOX/quarantine"

if [ ! -d "$Q" ] || [ ! -d "$SANDBOX/files" ]; then
  echo "❌ files/ or quarantine/ is missing; use reset to start over"
  exit 1
fi

EXPECTED="config-backup-03.txt
dana's export.txt
meeting notes 12.txt
note-17.txt
Q1 plan.txt
report-44.txt"

left="$(grep -rl 'NEBULA_KEY' "$SANDBOX/files" | wc -l | tr -d ' ')"
if [ "$left" -gt 0 ]; then
  echo "❌ $left file(s) under files/ still contain NEBULA_KEY"
  exit 1
fi

in_q="$(cd "$Q" && find . -type f | sed 's|^\./||' | LC_ALL=C sort)"
if [ "$in_q" != "$(printf '%s\n' "$EXPECTED" | LC_ALL=C sort)" ]; then
  if [ -z "$in_q" ]; then
    echo "❌ quarantine/ is empty, and files that contained NEBULA_KEY are gone from files/; were they deleted instead of moved?"
  elif printf '%s\n' "$in_q" | grep -q '/'; then
    echo "❌ put the files directly into quarantine/, without subfolders"
  else
    echo "❌ quarantine/ should hold exactly the files that contained NEBULA_KEY (it has $(printf '%s\n' "$in_q" | grep -c .))"
  fi
  exit 1
fi
while IFS= read -r f; do
  if ! grep -q 'NEBULA_KEY' "$Q/$f"; then
    echo "❌ quarantine/$f was changed; move the files, don't edit them"
    exit 1
  fi
done <<< "$EXPECTED"

total="$(find "$SANDBOX/files" -type f | wc -l | tr -d ' ')"
if [ "$total" -ne 196 ]; then
  echo "❌ files/ should still hold the 196 clean files, but has $total"
  exit 1
fi

echo "✅ all six files containing NEBULA_KEY are in quarantine/ and the clean files are untouched"
exit 0
