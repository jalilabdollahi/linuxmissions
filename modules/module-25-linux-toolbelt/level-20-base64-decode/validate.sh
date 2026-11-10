#!/bin/bash
SANDBOX="$1"
cd "$SANDBOX" || exit 1
st=.lm-state
[ -f ioc.txt ] || { echo "❌ ioc.txt does not exist yet"; exit 1; }
if cmp -s ioc.txt $st/expected; then
  echo "✅ ioc.txt names the C2 host and the dropped file"; exit 0
fi
n=$(grep -c . ioc.txt)
[ "$n" -eq 2 ] || { echo "❌ ioc.txt must have exactly two lines (c2=... and dropped=...), it has $n"; exit 1; }
host=$(sed -n 's/^c2=//p' $st/expected)
drop=$(sed -n 's/^dropped=//p' $st/expected)
grep -qxF "c2=$host" ioc.txt || { echo "❌ the c2= line is not the host the payload contacts (format c2=<host>, no scheme and no path)"; exit 1; }
grep -qxF "dropped=$drop" ioc.txt || { echo "❌ the dropped= line is not the path the payload writes to"; exit 1; }
echo "❌ both values are right, but the lines must be exactly c2=... then dropped=..."; exit 1
