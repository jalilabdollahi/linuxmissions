#!/bin/bash
# unexpected.txt = files with setuid/setgid not in the baseline (set recorded
# by setup.sh). Those lose both bits and keep their other bits; every other
# file keeps its mode exactly (baseline programs keep their s bits).
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mode() { stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1"; }
[ -s .lm-state/expected ] || { echo "❌ internal state missing, type 'reset'"; exit 1; }

if [ ! -f unexpected.txt ]; then echo "❌ unexpected.txt does not exist yet"; exit 1; fi
got=$(tr -d '\r' < unexpected.txt | sed -e 's|^rootfs||' -e 's|^\./||' -e 's|^\([^/]\)|/\1|' | grep -v '^$' | LC_ALL=C sort)
want=$(cat .lm-state/expected)
if [ "$got" != "$want" ]; then
  extra=$(comm -13 <(echo "$want") <(echo "$got") | head -1)
  if [ -n "$extra" ]; then
    if grep -qxF -- "$extra" suid-baseline.txt; then
      echo "❌ unexpected.txt lists $extra, which is in the baseline"
    elif [ ! -e "rootfs$extra" ]; then
      echo "❌ unexpected.txt lists $extra, which is not a file in rootfs/ (use paths as seen from inside the image)"
    else
      echo "❌ unexpected.txt lists $extra, which has no setuid/setgid bit to worry about"
    fi
  else
    echo "❌ unexpected.txt has $(echo "$got" | grep -c .) path(s) but there are more files with elevated bits outside the baseline"
  fi
  exit 1
fi

while IFS=$'\t' read -r p old; do
  if [ ! -f "$p" ]; then echo "❌ $p is gone"; exit 1; fi
  got=$(mode "$p"); path=${p#rootfs}
  if grep -qxF -- "$path" .lm-state/expected; then
    if [ $((8#$got & 8#6000)) -ne 0 ]; then echo "❌ $path is not in the baseline and still has setuid or setgid"; exit 1; fi
    exp=$(printf '%o' $((8#$old & 8#1777)))
  else
    exp=$old
  fi
  if [ "$got" != "$exp" ]; then
    if grep -qxF -- "$path" .lm-state/expected; then
      echo "❌ $path (mode $got) lost more than the two special bits: keep its other permissions as they were"
    elif [ $((8#$old & 8#6000)) -ne 0 ] && [ $((8#$got & 8#6000)) -eq 0 ]; then
      echo "❌ $path is in the baseline and must keep its setuid/setgid bit"
    else
      echo "❌ $path has mode $got; its other permissions must not change"
    fi
    exit 1
  fi
done < .lm-state/modes
echo "✅ $(wc -l < .lm-state/expected | tr -d ' ') unexpected setuid/setgid files found and neutralised; the baseline is untouched"
exit 0
