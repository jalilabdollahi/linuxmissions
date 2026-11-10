#!/bin/bash
# data/big.dat is still the same inode with link count 1; no other path shares it;
# every other file (identical copies, a different big.dat, an unrelated hard link
# pair) is still there with the same content.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -f data/big.dat ] || [ -L data/big.dat ]; then
  echo "❌ data/big.dat is gone: it has to stay as the only name of the data"
  exit 1
fi
if [ "$(stat -c %i data/big.dat)" != "$(cat .lm-state/inode)" ] || [ "$(sha256sum < data/big.dat | cut -d' ' -f1)" != "$(cat .lm-state/bighash)" ]; then
  echo "❌ data/big.dat is not the original file any more (a copy was put in its place?); keep the original data and remove the other names"
  exit 1
fi
links=$(stat -c %h data/big.dat)
if [ "$links" -ne 1 ]; then
  echo "❌ data/big.dat still has $links names (link count $links): $((links - 1)) more to find, hidden directories included"
  exit 1
fi
# nothing else may be missing or altered
NOW=$(find . -path ./.lm-state -prune -o -type f ! -samefile data/big.dat -printf '%P\n' | LC_ALL=C sort | while IFS= read -r p; do
  printf '%s\t%s\n' "$(sha256sum < "$p" | cut -d' ' -f1)" "$p"
done)
while IFS=$'\t' read -r h p; do
  if ! printf '%s\n' "$NOW" | grep -qxF -- "$h"$'\t'"$p"; then
    big=$(cat .lm-state/bighash)
    if [ "$h" = "$big" ]; then
      echo "❌ an identical copy of the dump ('$p') was deleted: it is a separate file with its own space, not another name of data/big.dat"
    else
      echo "❌ '$p' was deleted or changed: it was not a name of big.dat"
    fi
    exit 1
  fi
done < .lm-state/others
if [ "$(stat -c %h shared/a.txt)" != 2 ] || [ "$(stat -c %i shared/a.txt)" != "$(stat -c %i data/a-link.txt)" ]; then
  echo "❌ the hard-linked pair shared/a.txt and data/a-link.txt was broken: it had nothing to do with big.dat"
  exit 1
fi
echo "✅ data/big.dat is the only name of the dump (link count 1); the copies and the other links are untouched"
exit 0
