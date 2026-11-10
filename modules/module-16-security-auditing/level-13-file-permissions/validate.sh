#!/bin/bash
# findings.txt must be exactly the set of paths that needed fixing, each fixed to its
# safe mode (secrets 600/700, writable startup files lose group/other write), and no
# other path may change mode, content or link target.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
[ -s .lm-state/manifest ] || { echo "❌ internal state missing, type 'reset'"; exit 1; }
[ -s findings.txt ] || { echo "❌ findings.txt is missing or empty"; exit 1; }

# 1. nothing outside the findings may be touched
while IFS='|' read -r p t old want sha flag; do
  [ "$flag" = 1 ] && continue
  if [ "$t" = l ]; then
    [ -L "$p" ] && [ "$(readlink "$p")" = "$want" ] || { echo "❌ the symlink $p was changed"; exit 1; }
    continue
  fi
  [ -e "$p" ] || { echo "❌ $p is gone"; exit 1; }
  now=$(stat -c %a "$p")
  [ "$now" = "$old" ] || { echo "❌ $p changed from $old to $now but it was not a problem"; exit 1; }
  [ "$t" = f ] && [ "$(sha256sum < "$p" | cut -d' ' -f1)" != "$sha" ] && { echo "❌ the content of $p changed"; exit 1; }
done < .lm-state/manifest

# 2. every real finding has its safe mode
bad=0
while IFS='|' read -r p t old want sha flag; do
  [ "$flag" = 1 ] || continue
  now=$(stat -c %a "$p")
  [ "$now" = "$want" ] || { bad=$((bad + 1)); first=${first:-$p}; firstmode=$now; }
  [ "$t" = f ] && [ "$(sha256sum < "$p" | cut -d' ' -f1)" != "$sha" ] && { echo "❌ the content of $p changed"; exit 1; }
done < .lm-state/manifest
if [ "$bad" -gt 0 ]; then
  echo "❌ $bad exposed file(s) still have an unsafe mode, for example $first (now $firstmode)"; exit 1
fi

# 3. the report
norm() { sed -e 's/\r$//' -e "s#^$SANDBOX/##" -e 's#^\./##' -e 's/[[:space:]]*$//' -e '/^$/d' "$1" | LC_ALL=C sort -u; }
norm findings.txt > .lm-state/got
LC_ALL=C sort -u .lm-state/expected > .lm-state/want
extra=$(comm -13 .lm-state/want .lm-state/got | head -1)
[ -z "$extra" ] || { echo "❌ findings.txt lists $extra, which was not a problem (or is not written as home/...)"; exit 1; }
missing=$(comm -23 .lm-state/want .lm-state/got | wc -l)
[ "$missing" -eq 0 ] || { echo "❌ findings.txt lists $(wc -l < .lm-state/got) of $(wc -l < .lm-state/want) problem paths"; exit 1; }
echo "✅ $(wc -l < .lm-state/want) exposed paths fixed and reported, harmless files untouched"
exit 0
