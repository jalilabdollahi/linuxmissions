#!/bin/bash
# histogram.txt = 11 lines "label count bar", 100 ms buckets on elapsed ($2),
# 1000+ for everything from 1000 up, one # per full 10 requests.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -s .lm-state/results.sum ] || [ "$(cksum < results.jtl 2>/dev/null)" != "$(cat .lm-state/results.sum)" ]; then
  echo "❌ results.jtl was changed or removed; type 'reset' to restore it"
  exit 1
fi
if [ ! -f histogram.txt ]; then
  echo "❌ histogram.txt does not exist yet"
  exit 1
fi

# counts COLUMN UPPER: bucket counts (one per line) for a column; UPPER=1
# puts the boundary values in the lower bucket (the classic mistake).
counts() {
  awk -F, -v col="$1" -v upper="$2" 'NR > 1 { v = $col; b = int(v / 100); if (upper && v % 100 == 0 && v > 0) b--; if (b > 10) b = 10; c[b]++ }
    END { for (i = 0; i <= 10; i++) print c[i] + 0 }' results.jtl
}
EXPECTED=$(counts 2 0 | awk '{ bar = ""; for (j = 1; j <= int($1 / 10); j++) bar = bar "#"
  label = (NR <= 10) ? ((NR - 1) * 100 "-" (NR - 1) * 100 + 99) : "1000+"; print label " " $1 (bar == "" ? "" : " " bar) }')
GOT=$(tr -d '\r' < histogram.txt | sed 's/[[:space:]]*$//; /^$/d')
if [ "$GOT" = "$EXPECTED" ]; then
  echo "✅ histogram.txt: 11 buckets, $(awk 'NR > 1' results.jtl | wc -l | tr -d ' ') requests in total, empty buckets included"
  exit 0
fi

if [ -z "$GOT" ]; then echo "❌ histogram.txt is empty"; exit 1; fi
n=$(printf '%s\n' "$GOT" | wc -l | tr -d ' ')
if [ "$n" -ne 11 ]; then
  if [ "$n" -lt 11 ]; then
    echo "❌ histogram.txt has $n lines, expected 11: buckets with no requests must be listed too, with 0"
  else
    echo "❌ histogram.txt has $n lines, expected 11 (0-99 ... 900-999 and 1000+)"
  fi
  exit 1
fi
if [ "$(printf '%s\n' "$GOT" | cut -d' ' -f1)" != "$(printf '%s\n' "$EXPECTED" | cut -d' ' -f1)" ]; then
  echo "❌ the lines must start with the labels 0-99, 100-199, ... 900-999, 1000+ in that order"
  exit 1
fi
gotc=$(printf '%s\n' "$GOT" | cut -d' ' -f2)
if [ "$gotc" != "$(counts 2 0)" ]; then
  total=$(printf '%s\n' "$gotc" | awk '{ s += $1 } END { print s }')
  if [ "$gotc" = "$(counts 9 0)" ]; then
    echo "❌ these counts come from the Latency column; the histogram is about elapsed (column 2)"
  elif [ "$gotc" = "$(counts 2 1)" ]; then
    echo "❌ values of exactly 100, 200, ... 1000 are in the lower bucket; 100 belongs to 100-199 and 1000 to 1000+"
  elif [ "$total" -eq "$(awk 'END { print NR }' results.jtl)" ]; then
    echo "❌ the counts add up to $total, one more than there are requests: the header line was counted too"
  else
    echo "❌ the counts are not right (they add up to $total, there are $(awk 'NR > 1' results.jtl | wc -l | tr -d ' ') requests)"
  fi
  exit 1
fi
echo "❌ the counts are right, but not every bar has one # per full 10 requests (37 -> ###, 9 -> nothing)"
exit 1
