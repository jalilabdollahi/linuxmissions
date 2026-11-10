SANDBOX="$1"
cd "$SANDBOX" || exit 1
SANDBOX=$(pwd -P)
if [ ! -s .lm-state/rank ]; then echo "❌ the level's data is gone; type 'reset'"; exit 1; fi
[ -s top5.txt ] || { echo "❌ top5.txt is missing or empty"; exit 1; }
# paths only: last field, no ./, no absolute prefix, no trailing slash
awk 'NF {print $NF}' top5.txt | sed -E "s#^$SANDBOX/##; s#^\./##; s#/+\$##" > .lm-state/got
n=$(wc -l < .lm-state/got)
if [ "$n" != 5 ]; then echo "❌ top5.txt has $n entries, expected exactly 5"; exit 1; fi
i=0
while read -r p; do
  i=$((i+1))
  if ! echo "$p" | grep -qE '^var/[^/]+/[^/]+$'; then
    echo "❌ line $i ('$p') is not a directory exactly two levels below var/"; exit 1
  fi
done < .lm-state/got
if grep -qx 'var/lib/vm' .lm-state/got; then
  echo "❌ var/lib/vm is in your list because of its apparent size; most of that image is a hole and uses almost no disk"; exit 1
fi
g=$(grep -cxFf .lm-state/group .lm-state/got)
if [ "$g" -gt 1 ]; then
  echo "❌ $g backup snapshots are in your list; they share the same files through hard links, which must be counted once"; exit 1
fi
sed -E 's#^var/backups/snap-[0-9]$#@G#' .lm-state/got > .lm-state/got2
i=0
while read -r want; do
  i=$((i+1))
  have=$(sed -n "${i}p" .lm-state/got2)
  if [ "$have" != "$want" ]; then
    echo "❌ the ranking differs at position $i: '$have' is not the $i$( [ $i = 1 ] && echo st || { [ $i = 2 ] && echo nd || { [ $i = 3 ] && echo rd || echo th; }; } ) biggest by real disk usage (check hidden directories and use du's own sizes)"
    exit 1
  fi
done < .lm-state/rank
echo "✅ the five biggest directories by real usage, in the right order"
exit 0
