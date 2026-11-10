#!/bin/bash
# Every file's mode must equal old & mask (mask computed by setup.sh and kept
# in .lm-state/expected). Contents and directory modes must be unchanged.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mode() { stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1"; }
[ -s .lm-state/expected ] || { echo "❌ internal state missing, type 'reset'"; exit 1; }

n=0
while IFS=$'\t' read -r f want old; do
  if [ ! -f "$f" ]; then echo "❌ $f is missing"; exit 1; fi
  got=$(mode "$f"); got=$(printf '%03d' "$got")
  if [ "$(cksum < "$f" | sed "s|^|$f\t|")" != "$(grep -F "$f	" .lm-state/sums | head -1)" ]; then
    echo "❌ the content of $f was changed"; exit 1
  fi
  if [ "$got" != "$want" ]; then
    if [ $((8#$got & ~8#$old & 07777)) -ne 0 ]; then
      echo "❌ $f (now $got) has a permission it did not have before: a policy fix must never loosen a file"
    elif [ $((8#$got & ~8#$want & 07777)) -ne 0 ]; then
      echo "❌ $f (now $got) still grants permissions the policy does not allow"
    else
      echo "❌ $f (now $got) lost a permission it was allowed to keep: only remove what the policy forbids"
    fi
    exit 1
  fi
  n=$((n + 1))
done < .lm-state/expected

extra=$(find app -type f | wc -l | tr -d ' ')
if [ "$extra" != "$n" ]; then echo "❌ the number of files under app/ changed"; exit 1; fi
now=$(find app -type d | LC_ALL=C sort | while IFS= read -r d; do printf '%s\t%s\n' "$d" "$(mode "$d")"; done)
if [ "$now" != "$(cat .lm-state/dirs)" ]; then echo "❌ a folder mode was changed; the policy covers files only"; exit 1; fi
echo "✅ all $n files follow the policy and nothing that was already stricter got looser"
exit 0
