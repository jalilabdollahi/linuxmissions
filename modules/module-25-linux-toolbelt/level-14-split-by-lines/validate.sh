#!/bin/bash
# chunks/part-NN.csv: header first, <= 5000 data rows each, ceil(23417/5000) = 5
# files, and the data rows concatenated in order equal the source's data rows.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
src=.lm-state/customers.csv
[ -d chunks ] || { echo "❌ the directory chunks/ does not exist yet"; exit 1; }
cmp -s customers.csv $src || { echo "❌ customers.csv was modified; split a copy of the original"; exit 1; }
header=$(head -1 $src)
rows=$(($(wc -l < $src) - 1))
want=$(( (rows + 4999) / 5000 ))
names=$(ls chunks | tr '\n' ' ')
expected=$(for ((i = 0; i < want; i++)); do printf 'part-%02d.csv ' "$i"; done)
if [ "$names" != "$expected" ]; then
  echo "❌ chunks/ holds [${names% }], expected exactly $want files named part-00.csv, part-01.csv, ... in order"; exit 1
fi
tmp=$(mktemp "$SANDBOX/.lm-state/rows.XXXXXX"); trap 'rm -f "$tmp"' EXIT
for f in chunks/part-*.csv; do
  if [ "$(head -1 "$f")" != "$header" ]; then
    echo "❌ $f does not start with the header line"; exit 1
  fi
  n=$(($(wc -l < "$f") - 1))
  if [ "$n" -gt 5000 ]; then echo "❌ $f has $n data rows, the API accepts at most 5000"; exit 1; fi
  if [ "$f" != "chunks/part-$(printf '%02d' $((want - 1))).csv" ] && [ "$n" -ne 5000 ]; then
    echo "❌ $f has $n data rows, but every chunk except the last should be full"; exit 1
  fi
  tail -n +2 "$f" >> "$tmp"
done
if ! tail -n +2 $src | cmp -s - "$tmp"; then
  echo "❌ the data rows in the chunks do not add up to the rows of customers.csv (lost, duplicated, or a header repeated inside a chunk)"; exit 1
fi
echo "✅ $want chunks, each with the header and at most 5000 rows, and no row lost"
exit 0
