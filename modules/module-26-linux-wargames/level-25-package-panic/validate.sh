#!/bin/bash
SB="$1"; cd "$SB" || exit 1
for f in broken unsatisfied fix_order; do
  if [ ! -s $f.txt ]; then echo "❌ $f.txt is missing or empty"; exit 1; fi
done
cmpfile() {   # name
  tr -d '\r' < "$1.txt" | sed 's/[[:space:]]*$//' > .lm/got-$1.txt
  local m x
  m=$(grep -Fxvf .lm/got-$1.txt .lm/$1.txt | wc -l); x=$(grep -Fxvf .lm/$1.txt .lm/got-$1.txt | wc -l)
  if [ "$m" -gt 0 ] || [ "$x" -gt 0 ]; then echo "❌ $1.txt is wrong: $m expected line(s) missing, $x unexpected line(s) (format: see FORMAT.md)"; exit 1; fi
  if ! cmp -s .lm/got-$1.txt .lm/$1.txt; then echo "❌ $1.txt has the right lines but not sorted as FORMAT.md says"; exit 1; fi
}
cmpfile broken
cmpfile unsatisfied
# fix_order: same set, no duplicates, every dependency before its dependant
got=$(tr -d '\r' < fix_order.txt | sed 's/[[:space:]]*$//;/^$/d')
if [ "$(sort <<<"$got")" != "$(cat .lm/cfgset.txt)" ] || [ "$(wc -l <<<"$got")" -ne "$(wc -l < .lm/cfgset.txt)" ]; then
  echo "❌ fix_order.txt must list exactly the $(wc -l < .lm/cfgset.txt) packages that still need configuring, once each"; exit 1; fi
bad=0
while read -r d n; do
  pd=$(grep -nx "$d" <<<"$got" | cut -d: -f1); pn=$(grep -nx "$n" <<<"$got" | cut -d: -f1)
  [ "$pd" -lt "$pn" ] || bad=$((bad+1))
done < .lm/edges.txt
if [ "$bad" -gt 0 ]; then echo "❌ fix_order.txt puts $bad package(s) before something they depend on"; exit 1; fi
echo "✅ broken, unsatisfied and fix_order are all correct"
