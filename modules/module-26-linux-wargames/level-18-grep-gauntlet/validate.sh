#!/bin/bash
SB="$1"; cd "$SB" || exit 1
if [ ! -s trail.txt ]; then echo "❌ trail.txt is missing or empty"; exit 1; fi
tr -d '\r' < trail.txt > .lm/got.txt
total=$(wc -l < .lm/trail.txt)
missing=$(grep -Fxvf .lm/got.txt .lm/trail.txt | wc -l)
extra=$(grep -Fxvf .lm/trail.txt .lm/got.txt | wc -l)
if [ "$missing" -gt 0 ] && [ "$extra" -gt 0 ]; then echo "❌ trail.txt is missing $missing of the $total expected lines and has $extra line(s) that are not about this order"; exit 1; fi
if [ "$missing" -gt 0 ]; then echo "❌ trail.txt is missing $missing of the $total expected lines (look at every service, every rotation, every spelling of the ID)"; exit 1; fi
if [ "$extra" -gt 0 ]; then echo "❌ trail.txt has $extra line(s) that are not about this order"; exit 1; fi
if [ "$(sort .lm/got.txt | uniq -d | wc -l)" -gt 0 ] || [ "$(wc -l < .lm/got.txt)" -ne "$total" ]; then echo "❌ trail.txt has duplicated lines"; exit 1; fi
if ! cmp -s .lm/got.txt .lm/trail.txt; then echo "❌ all the lines are there but not in the order the events happened (services use different time formats)"; exit 1; fi
echo "✅ trail.txt holds every line about the order, in time order"
