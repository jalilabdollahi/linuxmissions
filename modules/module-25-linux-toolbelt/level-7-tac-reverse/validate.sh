#!/bin/bash
# CHANGES.newest-first = blocks (each starting at a "----" line) in reverse
# order, each block unchanged.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
if [ "$(cksum < CHANGES 2>/dev/null)" != "$(cat .lm-state/changes.sum)" ]; then
  echo "❌ CHANGES was changed; type 'reset' to restore it"; exit 1
fi
if [ ! -f CHANGES.newest-first ]; then echo "❌ CHANGES.newest-first does not exist yet"; exit 1; fi
expect=$(mktemp "$SANDBOX/.lm-state/expect.XXXXXX"); trap 'rm -f "$expect"' EXIT
awk '/^----$/ { n++ } { b[n] = b[n] $0 "\n" } END { for (i = n; i >= 1; i--) printf "%s", b[i] }' CHANGES > "$expect"
if cmp -s CHANGES.newest-first "$expect"; then
  echo "✅ CHANGES.newest-first: $(grep -c '^----$' "$expect") release blocks, newest first, each intact"
  exit 0
fi
blocks=$(grep -c '^----$' CHANGES)
if [ "$(wc -l < CHANGES.newest-first)" -ne "$(wc -l < CHANGES)" ] && [ ! -s CHANGES.newest-first ]; then
  echo "❌ CHANGES.newest-first is empty"
elif cmp -s CHANGES.newest-first <(tac CHANGES); then
  echo "❌ the whole file was reversed line by line: the lines inside each release are upside down and the ---- lines sit at the end of their blocks"
elif [ "$(head -1 CHANGES.newest-first)" != "----" ]; then
  echo "❌ the first line should be a ---- separator: every block must keep its ---- line in front of it"
elif [ "$(grep -c '^----$' CHANGES.newest-first)" -ne "$blocks" ]; then
  echo "❌ CHANGES.newest-first has $(grep -c '^----$' CHANGES.newest-first) ---- lines, expected $blocks"
elif [ "$(sort CHANGES.newest-first)" = "$(sort CHANGES)" ]; then
  echo "❌ all the lines are there, but not as intact blocks in reverse order (check the line inside each block and the block order)"
else
  echo "❌ CHANGES.newest-first does not contain exactly the lines of CHANGES"
fi
exit 1
