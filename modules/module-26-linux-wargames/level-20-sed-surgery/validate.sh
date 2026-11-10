#!/bin/bash
SB="$1"; cd "$SB" || exit 1
bad=0; first=""
for o in .lm/orig/*.conf; do
  b=$(basename "$o"); f=conf/$b
  if [ ! -f "$f" ]; then echo "❌ $f is missing"; exit 1; fi
  if ! cmp -s "$f" ".lm/expected/$b"; then
    bad=$((bad+1)); [ -z "$first" ] && first="$f line $(cmp "$f" ".lm/expected/$b" 2>&1 | grep -o 'line [0-9]*' | head -1 | cut -d' ' -f2)"
  fi
done
if [ "$bad" -gt 0 ]; then echo "❌ $bad of 40 configs are not as required (first difference: $first)"; exit 1; fi
nb=0
for o in .lm/orig/*.conf; do
  b=$(basename "$o")
  if ! cmp -s "$o" ".lm/expected/$b"; then
    if [ ! -f "conf/$b.bak" ]; then nb=$((nb+1)); elif ! cmp -s "$o" "conf/$b.bak"; then echo "❌ conf/$b.bak is not the original of conf/$b"; exit 1; fi
  elif [ -f "conf/$b.bak" ] && ! cmp -s "$o" "conf/$b.bak"; then echo "❌ conf/$b.bak is not the original"; exit 1; fi
done
if [ "$nb" -gt 0 ]; then echo "❌ $nb changed config(s) have no .bak backup of the original"; exit 1; fi
echo "✅ all 40 configs edited in the right sections only, with .bak originals kept"
