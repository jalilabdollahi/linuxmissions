#!/bin/bash
# console.txt must be byte-identical to the clean session that setup.sh
# dirtied (only its checksum and line count are kept).
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -s .lm-state/clean.sum ] || [ ! -s .lm-state/raw.sum ]; then
  echo "❌ the level's reference data in .lm-state/ is gone; type 'reset'"
  exit 1
fi
if [ "$(cksum < console.raw 2>/dev/null)" != "$(cat .lm-state/raw.sum)" ]; then
  echo "❌ console.raw was changed or removed; type 'reset' to restore it"
  exit 1
fi
if [ ! -f console.txt ]; then
  echo "❌ console.txt does not exist yet"
  exit 1
fi
if [ "$(cksum < console.txt)" = "$(cat .lm-state/clean.sum)" ]; then
  echo "✅ console.txt is clean: no CRs, NULs, bells or colour codes, tabs and lines intact"
  exit 0
fi

count() { LC_ALL=C tr -cd "$1" < console.txt | wc -c | tr -d ' '; }
want=$(cat .lm-state/lines)
got=$(wc -l < console.txt | tr -d ' ')
if [ "$got" -le 1 ] && [ "$want" -gt 1 ]; then
  echo "❌ console.txt is a single line: the newlines were deleted too (they are not printable characters)"
  exit 1
fi
if [ "$(count '\r')" -gt 0 ]; then
  echo "❌ console.txt still has $(count '\r') carriage returns (\\r)"
  exit 1
fi
if [ "$(count '\000')" -gt 0 ]; then
  echo "❌ console.txt still has $(count '\000') NUL bytes"
  exit 1
fi
if [ "$(count '\007')" -gt 0 ]; then
  echo "❌ console.txt still has $(count '\007') bell characters (\\a, shown as ^G)"
  exit 1
fi
if [ "$(count '\033')" -gt 0 ]; then
  echo "❌ console.txt still has $(count '\033') ANSI escape sequences (ESC, shown as ^[, followed by [...m)"
  exit 1
fi
if grep -q '\[[0-9;]*m' console.txt; then
  echo "❌ console.txt has leftovers like '$(grep -o '\[[0-9;]*m' console.txt | head -1)': the ESC byte is gone but the rest of the colour code is still there"
  exit 1
fi
if [ "$(count '\t')" -eq 0 ]; then
  echo "❌ the tabs between the columns of /etc/hosts are gone; only control characters that are junk should go"
  exit 1
fi
if [ "$got" -ne "$want" ]; then
  echo "❌ console.txt has $got lines, the session has $want (keep empty lines, but don't add any)"
  exit 1
fi
echo "❌ console.txt has the right number of lines but differs from the clean session (was printable text removed or changed?)"
exit 1
