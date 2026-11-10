#!/bin/bash
# faults.txt: "timestamp sensor value" for every record with status != 0, file
# order. Timestamp and sensor exact, value within 0.01.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
exp=.lm-state/expected
[ -f faults.txt ] || { echo "❌ faults.txt does not exist yet"; exit 1; }
want=$(wc -l < $exp)
have=$(grep -c . faults.txt)
if [ "$have" -ne "$want" ]; then
  echo "❌ faults.txt has $have lines, but the file holds a different number of faulty records: check where the records start and which field is the status"; exit 1
fi
res=$(paste -d'|' $exp faults.txt | awk -F'|' '
  { split($1, e, " "); n = split($2, g, " ")
    if (n != 3) { print "fields " NR; exit }
    if (e[1] != g[1] + 0) { print "ts " NR; exit }
    if (e[2] != g[2] + 0) { print "sensor " NR; exit }
    d = e[3] - g[3]; if (d < 0) d = -d
    if (d > 0.01) { print "value " NR; exit } }')
case "$res" in
  "") echo "✅ faults.txt matches the faulty records of sensors.bin"; exit 0 ;;
  fields*) echo "❌ line ${res#fields } of faults.txt must have exactly three fields: timestamp sensor value" ;;
  ts*) echo "❌ line ${res#ts } has a wrong timestamp: check where the records start and the byte order" ;;
  sensor*) echo "❌ line ${res#sensor } has the right timestamp but a wrong sensor id: check the field offsets inside the record" ;;
  value*) echo "❌ line ${res#value } has the right timestamp and sensor but a wrong value: is it read as a 4-byte float?" ;;
esac
exit 1
