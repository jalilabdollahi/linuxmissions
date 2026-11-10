#!/bin/bash
# Expected table (written by setup.sh): dirs 755, files that were executable
# 755, other files 644. Contents unchanged, no entries added or removed.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mode() { stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1"; }
[ -s .lm-state/expected ] || { echo "❌ internal state missing, type 'reset'"; exit 1; }
[ -d etc-app ] || { echo "❌ etc-app/ is missing"; exit 1; }

if ! find etc-app -type f | LC_ALL=C sort | xargs cksum | cmp -s - .lm-state/sums; then
  echo "❌ a file in etc-app/ was changed, added or removed; only permissions should change"; exit 1
fi
total=$(wc -l < .lm-state/expected | tr -d ' ')
have=$(find etc-app | wc -l | tr -d ' ')
[ "$have" = "$total" ] || { echo "❌ etc-app/ has $have entries, expected $total"; exit 1; }

# Report the most telling problem first: writable, then executable data, then unreadable.
bad=""
while IFS=$'\t' read -r p want; do
  got=$(mode "$p")
  [ "$got" = "$want" ] && continue
  if [ $((8#$got & 8#022)) -ne 0 ]; then
    echo "❌ $p is still writable by group or others (mode $got)"; exit 1
  fi
  [ -z "$bad" ] && bad="$p	$got	$want"
done < .lm-state/expected
if [ -n "$bad" ]; then
  IFS=$'\t' read -r p got want <<< "$bad"
  if [ -d "$p" ]; then
    echo "❌ folder $p has mode $got: everybody must be able to read and enter it, and only the owner may write"
  elif [ $((8#$got & 8#111)) -ne 0 ] && [ $((8#$want & 8#111)) -eq 0 ]; then
    echo "❌ $p (mode $got) became executable, but it is a plain data file"
  elif [ $((8#$want & 8#111)) -ne 0 ]; then
    echo "❌ $p (mode $got) is a script and must stay executable for everyone"
  else
    echo "❌ $p has mode $got: everybody should be able to read it"
  fi
  exit 1
fi
echo "✅ etc-app/ is read-only for everyone but the owner; folders and scripts are still usable and data files are not executable"
exit 0
