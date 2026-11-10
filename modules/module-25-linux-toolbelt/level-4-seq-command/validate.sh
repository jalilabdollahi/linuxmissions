#!/bin/bash
# labels.txt = rack-<letter>-<NN> for first, first+2 ... last, exact.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
read -r letter first last < .lm-state/params
if [ ! -f labels.txt ]; then echo "❌ labels.txt does not exist yet"; exit 1; fi
expect=$(mktemp "$SANDBOX/.lm-state/expect.XXXXXX"); trap 'rm -f "$expect"' EXIT
awk -v l="$letter" -v f="$first" -v e="$last" 'BEGIN { for (i = f; i <= e; i += 2) printf "rack-%s-%02d\n", l, i }' > "$expect"
if cmp -s labels.txt "$expect"; then
  echo "✅ labels.txt: $(wc -l < "$expect" | tr -d ' ') labels, rack-$letter-$(printf '%02d' "$first") to rack-$letter-$last"
  exit 0
fi
want=$(wc -l < "$expect" | tr -d ' '); got=$(wc -l < labels.txt | tr -d ' ')
if grep -qE -- "-[0-9]$" labels.txt; then
  echo "❌ some labels end in a single digit (like $(grep -m1 -E -- '-[0-9]$' labels.txt)); the printer needs two"
elif grep -qE -- "-0[0-9]{2}$" labels.txt; then
  echo "❌ some labels have three digits (like $(grep -m1 -E -- '-0[0-9]{2}$' labels.txt)); two digits are enough"
elif [ "$got" -ne "$want" ]; then
  echo "❌ labels.txt has $got lines, expected $want: check the first position, the last one and the step"
elif ! grep -q -- "^rack-$letter-" labels.txt; then
  echo "❌ the labels do not start with rack-$letter-"
else
  echo "❌ labels.txt has the right number of lines but differs from the request (first difference: line $(cmp labels.txt "$expect" 2>&1 | sed -n 's/.*line \([0-9]*\).*/\1/p'))"
fi
exit 1
