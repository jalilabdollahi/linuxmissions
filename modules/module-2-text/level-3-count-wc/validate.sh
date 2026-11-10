#!/bin/bash
# $1 = sandbox path
SANDBOX="$1"
cd "$SANDBOX" || exit 1

# access.log must be the original (otherwise the numbers mean nothing)
if [ "$(cksum < access.log 2>/dev/null)" != "3490258851 150976" ]; then
  echo "❌ access.log was changed or removed; type 'reset' to restore it"
  exit 1
fi
if [ ! -f report.txt ]; then
  echo "❌ report.txt does not exist yet"
  exit 1
fi

# Expected values, computed from the log
REQ=$(wc -l < access.log | tr -d ' ')
IPS=$(awk '{print $1}' access.log | sort -u | wc -l | tr -d ' ')
BYTES=$(awk '$10 != "-" {s += $10} END {print s}' access.log)

# Read report.txt (spaces and Windows line endings are tolerated)
REPORT=$(tr -d '\r \t' < report.txt | grep -v '^$')
lines=$(printf '%s\n' "$REPORT" | grep -c .)
value() { printf '%s\n' "$REPORT" | sed -n "s/^$1=//p"; }

for key in requests unique_ips bytes; do
  n=$(printf '%s\n' "$REPORT" | grep -c "^$key=")
  if [ "$n" -ne 1 ]; then
    echo "❌ report.txt needs exactly one line starting with $key= (found $n)"
    exit 1
  fi
done
if [ "$lines" -ne 3 ]; then
  echo "❌ report.txt should have exactly 3 lines, it has $lines"
  exit 1
fi
[ "$(value requests)" = "$REQ" ] || { echo "❌ requests= is not the number of lines (requests) in access.log"; exit 1; }
[ "$(value unique_ips)" = "$IPS" ] || { echo "❌ unique_ips= is wrong: count each client IP (field 1) only once"; exit 1; }
[ "$(value bytes)" = "$BYTES" ] || { echo "❌ bytes= is wrong: add up the size field after the status code (field 10)"; exit 1; }
echo "✅ report.txt: $REQ requests from $IPS IPs, $BYTES bytes"
exit 0
