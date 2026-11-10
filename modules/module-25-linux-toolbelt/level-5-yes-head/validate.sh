#!/bin/bash
# install.done written by the real script, and load.txt = 1000 x "ping".
SANDBOX="$1"
cd "$SANDBOX" || exit 1
if [ ! -f install.done ]; then
  echo "❌ install.done does not exist: the installer has not completed yet"; exit 1
fi
if ! cmp -s install.done .lm-state/done.expected; then
  echo "❌ install.done was not written by a complete run of ./install.sh"; exit 1
fi
if [ ! -f load.txt ]; then echo "❌ load.txt does not exist yet"; exit 1; fi
size=$(wc -c < load.txt | tr -d ' ')
if [ "$size" -gt 100000 ]; then
  echo "❌ load.txt is $size bytes: it should hold exactly 1000 short lines (is something still writing to it?)"; exit 1
fi
lines=$(wc -l < load.txt | tr -d ' ')
if [ "$lines" -ne 1000 ]; then echo "❌ load.txt has $lines lines, expected exactly 1000"; exit 1; fi
other=$(grep -cvx 'ping' load.txt)
if [ "$other" -gt 0 ]; then echo "❌ $other line(s) in load.txt are not exactly 'ping'"; exit 1; fi
echo "✅ installer finished unattended and load.txt holds 1000 pings"
exit 0
