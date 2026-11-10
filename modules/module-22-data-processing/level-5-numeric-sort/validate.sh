#!/bin/bash
# top10.txt = the 10 data rows with the largest value (general numeric), descending.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -s .lm-state/readings.sum ] || [ "$(cksum < readings.csv 2>/dev/null)" != "$(cat .lm-state/readings.sum)" ]; then
  echo "❌ readings.csv was changed or removed; type 'reset' to restore it"
  exit 1
fi
if [ ! -f top10.txt ]; then
  echo "❌ top10.txt does not exist yet"
  exit 1
fi

# awk converts 1.2e3 to 1200 the same way sort -g does; values are unique.
EXPECTED=$(awk -F, 'NR > 1 { printf "%.4f\t%s\n", $3, $0 }' readings.csv | sort -t "$(printf '\t')" -k1,1nr | head -n 10 | cut -f2-)
GOT=$(tr -d '\r' < top10.txt | sed '/^[[:space:]]*$/d')
if [ "$GOT" = "$EXPECTED" ]; then
  echo "✅ top10.txt: the 10 highest readings, from $(printf '%s\n' "$EXPECTED" | head -n 1 | cut -d, -f3) down to $(printf '%s\n' "$EXPECTED" | tail -n 1 | cut -d, -f3)"
  exit 0
fi

if [ -z "$GOT" ]; then echo "❌ top10.txt is empty"; exit 1; fi
if printf '%s\n' "$GOT" | grep -q '^sensor,'; then
  echo "❌ top10.txt contains the header line; only data rows belong in it"
  exit 1
fi
n=$(printf '%s\n' "$GOT" | wc -l | tr -d ' ')
if [ "$n" -ne 10 ]; then
  echo "❌ top10.txt has $n lines, expected exactly 10"
  exit 1
fi
if [ "$(printf '%s\n' "$GOT" | sort)" = "$(printf '%s\n' "$EXPECTED" | sort)" ]; then
  echo "❌ these are the right 10 readings, but not in order from the highest value down"
  exit 1
fi
DATA=$(tail -n +2 readings.csv)
if printf '%s\n' "$GOT" | cut -d, -f3 | grep -q '^-'; then
  echo "❌ top10.txt contains negative readings; the highest values come first"
  exit 1
fi
if [ "$GOT" = "$(printf '%s\n' "$DATA" | sort -t, -k3,3r | head -n 10)" ]; then
  echo "❌ top10.txt is sorted as text (character by character, so 9 beats 12); compare the values as numbers"
  exit 1
fi
missing=$(printf '%s\n' "$EXPECTED" | grep -vxF -f <(printf '%s\n' "$GOT") | cut -d, -f3 | grep -i e | head -n 1)
if [ -n "$missing" ]; then
  echo "❌ top10.txt misses the reading $missing ($(awk -v v="$missing" 'BEGIN { print v + 0 }')); a plain numeric sort stops reading at the e"
  exit 1
fi
echo "❌ top10.txt does not hold the 10 highest values; compare the third column as a number, not as text"
exit 1
