#!/bin/bash
# $1 = sandbox path
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -f app.log ] || [ "$(wc -l < app.log | tr -d ' ')" -ne 2500 ]; then
  echo "❌ app.log was changed or removed; type 'reset' to restore it"
  exit 1
fi
if [ ! -f errors.txt ]; then
  echo "❌ errors.txt does not exist yet"
  exit 1
fi

EXPECTED=$(grep -E 'ERROR|FATAL' app.log)
GOT=$(tr -d '\r' < errors.txt)
if [ "$GOT" = "$EXPECTED" ]; then
  echo "✅ errors.txt holds all $(printf '%s\n' "$EXPECTED" | wc -l | tr -d ' ') ERROR and FATAL lines, in order"
  exit 0
fi

want=$(printf '%s\n' "$EXPECTED" | wc -l | tr -d ' ')
got=$(printf '%s\n' "$GOT" | grep -c .)
wrong=$(printf '%s\n' "$GOT" | grep -c -v -E 'ERROR|FATAL')
nfatal=$(printf '%s\n' "$GOT" | grep -c 'FATAL')
if [ "$wrong" -gt 0 ]; then
  echo "❌ errors.txt has $wrong line(s) that contain neither ERROR nor FATAL (grep is case-sensitive unless told otherwise)"
elif [ "$nfatal" -eq 0 ]; then
  echo "❌ errors.txt has no FATAL lines yet"
elif [ "$got" -ne "$want" ]; then
  echo "❌ errors.txt has $got lines; app.log has a different number of ERROR/FATAL lines"
else
  echo "❌ errors.txt has the right number of lines but not in app.log's order (don't sort them)"
fi
exit 1
