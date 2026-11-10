#!/bin/bash
# $1 = sandbox path
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ "$(cksum < users.csv 2>/dev/null)" != "1985041708 5184" ]; then
  echo "❌ users.csv was changed or removed; type 'reset' to restore it"
  exit 1
fi
if [ ! -f extract.csv ]; then
  echo "❌ extract.csv does not exist yet"
  exit 1
fi

EXPECTED=$(awk -F, 'NR > 1 && $5 == "active" {print $1 "," $3}' users.csv)
GOT=$(tr -d '\r' < extract.csv | grep -v '^$')
if [ "$GOT" = "$EXPECTED" ]; then
  echo "✅ extract.csv lists the $(printf '%s\n' "$EXPECTED" | wc -l | tr -d ' ') active users as username,email"
  exit 0
fi

if printf '%s\n' "$GOT" | grep -q '^username'; then
  echo "❌ extract.csv starts with the header line; billing wants data rows only"
  exit 1
fi
if printf '%s\n' "$GOT" | awk -F, 'NF != 2 {bad=1} END {exit !bad}'; then
  echo "❌ every line of extract.csv must have exactly two comma-separated fields: username,email"
  exit 1
fi
# Which users did the player include?
inactive=$(printf '%s\n' "$GOT" | cut -d, -f1 | grep -cxF -f <(awk -F, 'NR > 1 && $5 != "active" {print $1}' users.csv))
want=$(printf '%s\n' "$EXPECTED" | wc -l | tr -d ' ')
got=$(printf '%s\n' "$GOT" | grep -c .)
if [ "$inactive" -gt 0 ]; then
  echo "❌ extract.csv includes $inactive user(s) whose status is not exactly active (note: 'inactive' contains 'active')"
elif [ "$got" -ne "$want" ]; then
  echo "❌ extract.csv has $got users, but $want users are active"
else
  echo "❌ extract.csv has the right number of lines, but the fields or the order are not right (username first, then email)"
fi
exit 1
