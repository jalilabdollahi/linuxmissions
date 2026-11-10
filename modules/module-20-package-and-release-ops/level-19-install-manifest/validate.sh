#!/bin/bash
SANDBOX="$1"
cd "$SANDBOX" || exit 1
export LC_ALL=C
if [ ! -s MANIFEST ]; then
  echo "❌ MANIFEST does not exist yet (or is empty)"
  exit 1
fi
n=$(grep -vnE '^[0-7]{3,4} [0-9a-f]{64} [^ ]' MANIFEST | head -1 | cut -d: -f1)
if [ -n "$n" ]; then
  echo "❌ MANIFEST line $n is not 'MODE SHA256 PATH' (octal mode, 64 hex digits, then the path, single spaces)"
  exit 1
fi
if grep -qE ' (\./|/)' MANIFEST; then
  echo "❌ MANIFEST paths must be relative to release/ without a leading ./ or /"
  exit 1
fi
want=$(wc -l < .lm/MANIFEST.expected)
have=$(wc -l < MANIFEST)
if [ "$have" -ne "$want" ]; then
  echo "❌ MANIFEST has $have lines, release/ has $want regular files"
  exit 1
fi
if ! diff -q <(sort MANIFEST) <(sort .lm/MANIFEST.expected) >/dev/null; then
  bad=$(comm -23 <(sort MANIFEST) <(sort .lm/MANIFEST.expected) | wc -l)
  echo "❌ MANIFEST has $bad line(s) with a wrong mode, hash or path (compare with the files in release/)"
  exit 1
fi
if ! cmp -s MANIFEST .lm/MANIFEST.expected; then
  echo "❌ MANIFEST lines are right but not sorted by path"
  exit 1
fi
if [ ! -f deploy-diff.txt ]; then
  echo "✅ MANIFEST is correct, but deploy-diff.txt is still missing"
  exit 1
fi
if grep -vqE '^(MODIFIED|MISSING|EXTRA) [^ ]' deploy-diff.txt; then
  echo "❌ deploy-diff.txt lines must look like 'MODIFIED path', 'MISSING path' or 'EXTRA path'"
  exit 1
fi
sort deploy-diff.txt > .lm/dd.got
sort .lm/deploy-diff.expected > .lm/dd.want
if [ "$(uniq -d < .lm/dd.got | wc -l)" -gt 0 ]; then
  echo "❌ deploy-diff.txt lists a line twice"
  exit 1
fi
if ! cmp -s .lm/dd.got .lm/dd.want; then
  miss=$(comm -13 .lm/dd.got .lm/dd.want | wc -l)
  extra=$(comm -23 .lm/dd.got .lm/dd.want | wc -l)
  echo "❌ deploy-diff.txt is not right: $miss expected line(s) missing or wrong, $extra line(s) that should not be there (mode-only changes count too; check names with spaces)"
  exit 1
fi
echo "✅ MANIFEST is exact and deploy-diff.txt lists all $(wc -l < deploy-diff.txt) differences"
