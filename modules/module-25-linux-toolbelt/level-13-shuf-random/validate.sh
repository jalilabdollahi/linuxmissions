#!/bin/bash
# sample.csv must equal a draw of 25 data rows of tx.csv made with seed.bin
# as the random source.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
st=.lm-state
[ -f sample.csv ] || { echo "❌ sample.csv does not exist yet"; exit 1; }
if ! cmp -s tx.csv $st/tx.csv || ! cmp -s seed.bin $st/seed.bin; then
  echo "❌ tx.csv or seed.bin was modified; the draw has to be made from the originals"; exit 1
fi
n=$(wc -l < sample.csv)
[ "$n" -eq 25 ] || { echo "❌ sample.csv has $n lines, the auditor asked for 25"; exit 1; }
if grep -qx 'tx_id,date,customer,currency,amount' sample.csv; then
  echo "❌ the header line is part of the sample: it is not a transaction"; exit 1
fi
bad=$(grep -vxFf $st/tx.csv sample.csv | head -1)
[ -z "$bad" ] || { echo "❌ sample.csv contains a line that is not in tx.csv: $bad"; exit 1; }
if [ "$(sort sample.csv | uniq -d | wc -l)" -ne 0 ]; then
  echo "❌ the same transaction appears twice in the sample"; exit 1
fi
# shuf picks differently when it reads a pipe or a regular file, and -n or head
# differ too; all of these are repeatable draws from seed.bin, so each is accepted.
tail -n +2 $st/tx.csv > $st/pop.csv
tail -n +2 $st/tx.csv | shuf -n 25 --random-source=$st/seed.bin > $st/exp1.csv
shuf -n 25 --random-source=$st/seed.bin $st/pop.csv > $st/exp2.csv
tail -n +2 $st/tx.csv | shuf --random-source=$st/seed.bin | head -n 25 > $st/exp3.csv
shuf --random-source=$st/seed.bin $st/pop.csv | head -n 25 > $st/exp4.csv
for e in 1 2 3 4; do
  if cmp -s sample.csv $st/exp$e.csv; then
    echo "✅ sample.csv is a repeatable 25-line draw from seed.bin"; exit 0
  fi
done
if [ "$(sort sample.csv)" = "$(sort $st/exp1.csv)" ]; then
  echo "❌ right 25 transactions but a different order; repeat the draw exactly, without re-sorting"; exit 1
fi
echo "❌ a valid sample, but not the one seed.bin gives: the draw must use seed.bin so it can be repeated"; exit 1
