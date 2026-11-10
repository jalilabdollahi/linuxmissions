#!/bin/bash
# inventory.csv: exact header, and the exact set of rows (order does not matter).
SANDBOX="$1"
cd "$SANDBOX" || exit 1
[ -f inventory.csv ] || { echo "❌ inventory.csv does not exist yet"; exit 1; }
tr -d '\r' < inventory.csv > .lm-state/got.csv
if [ "$(head -n1 .lm-state/got.csv)" != "file,TYPE,UUID,LABEL" ]; then
  echo "❌ the first line of inventory.csv must be exactly: file,TYPE,UUID,LABEL"
  exit 1
fi
tail -n +2 .lm-state/got.csv | sed '/^[[:space:]]*$/d' | LC_ALL=C sort > .lm-state/got.rows
if cmp -s .lm-state/got.rows .lm-state/expect; then
  echo "✅ inventory.csv lists every image and partition exactly as blkid sees them"
  exit 0
fi
n=$(wc -l < .lm-state/got.rows); w=$(wc -l < .lm-state/expect)
while IFS=, read -r f t u l; do
  row=$(grep -m1 -F "$f," .lm-state/got.rows | grep "^$f,")
  if [ -z "$row" ]; then
    case "$f" in
      *@p*) echo "❌ no line for the partition $f (an image with a partition table has no file system of its own: probe each partition)" ;;
      *) echo "❌ no line for $f" ;;
    esac
    exit 1
  fi
  IFS=, read -r _ gt gu gl <<< "$row"
  if [ "$gt" != "$t" ]; then echo "❌ the TYPE of $f is wrong (the file has: '$gt')"; exit 1; fi
  if [ "$gu" != "$u" ]; then echo "❌ the UUID of $f is wrong"; exit 1; fi
  if [ "$gl" != "$l" ]; then echo "❌ the LABEL of $f is wrong (an image without a label leaves it empty)"; exit 1; fi
done < .lm-state/expect
echo "❌ inventory.csv has $n rows but the images need $w: there is a row for something that is not an image or a partition, or a duplicate"
exit 1
