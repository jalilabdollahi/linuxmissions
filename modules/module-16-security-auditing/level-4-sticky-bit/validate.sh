#!/bin/bash
# The vulnerable set is computed by setup.sh (.lm-state/expected). Check that
# modes of every entry equal the original (plus the sticky bit for the
# vulnerable directories), links are intact, and fixed.txt is that same set.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mode() { stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1"; }
[ -s .lm-state/expected ] || { echo "❌ internal state missing, type 'reset'"; exit 1; }
[ -d srv ] || { echo "❌ srv/ is missing"; exit 1; }

now=$(find srv -type l | LC_ALL=C sort | while IFS= read -r p; do printf '%s\t%s\n' "$p" "$(readlink "$p")"; done)
[ "$now" = "$(cat .lm-state/links)" ] || { echo "❌ a symbolic link under srv/ was changed or removed"; exit 1; }

while IFS=$'\t' read -r p old; do
  if [ ! -e "$p" ]; then echo "❌ $p is missing"; exit 1; fi
  got=$(mode "$p")
  if grep -qxF -- "$p" .lm-state/expected; then
    if [ $((8#$got & 8#1000)) -eq 0 ]; then
      echo "❌ $p is world-writable and still has no sticky bit"; exit 1
    fi
    want=$(printf '%o' $((8#$old | 8#1000)))
  else
    want=$old
  fi
  if [ "$got" != "$want" ]; then
    if [ -d "$p" ]; then echo "❌ the directory $p has mode $got but only the sticky bit should have been added where needed"
    else echo "❌ the file $p has mode $got: files were not supposed to change"; fi
    exit 1
  fi
done < .lm-state/modes

if [ ! -f fixed.txt ]; then echo "❌ the directories are fixed, but fixed.txt does not exist yet"; exit 1; fi
got=$(tr -d '\r' < fixed.txt | sed -e 's|^\./||' -e 's|/*$||' | grep -v '^$' | LC_ALL=C sort)
want=$(cat .lm-state/expected)
if [ "$got" != "$want" ]; then
  extra=$(comm -13 <(echo "$want") <(echo "$got") | head -1)
  miss=$(comm -23 <(echo "$want") <(echo "$got") | head -1)
  if [ -n "$extra" ]; then
    if [ -L "$extra" ]; then echo "❌ fixed.txt lists $extra, which is a symbolic link, not a directory that needed fixing"
    elif [ ! -e "$extra" ]; then echo "❌ fixed.txt lists $extra, which does not exist (write paths as find prints them, starting with srv/)"
    else echo "❌ fixed.txt lists $extra, which was not one of the vulnerable directories"; fi
  else
    echo "❌ fixed.txt lists $(echo "$got" | grep -c .) director(ies) but more were vulnerable (is a hidden or oddly named one missing?)"
  fi
  exit 1
fi
echo "✅ $(echo "$want" | grep -c .) shared directories now have the sticky bit and fixed.txt lists them"
exit 0
