#!/bin/bash
# billing.dat must equal ACCT%06d|%-12.12s|%10.2f for every data line.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
if [ "$(cksum < accounts.csv 2>/dev/null)" != "$(cat .lm-state/accounts.sum)" ]; then
  echo "❌ accounts.csv was changed or removed; type 'reset' to restore it"; exit 1
fi
if [ ! -f billing.dat ]; then echo "❌ billing.dat does not exist yet"; exit 1; fi

expect=$(mktemp "$SANDBOX/.lm-state/expect.XXXXXX"); trap 'rm -f "$expect"' EXIT
awk -F, 'NR > 1 { printf "ACCT%06d|%-12.12s|%10.2f\n", $1, $2, $3 }' accounts.csv > "$expect"

if cmp -s billing.dat "$expect"; then
  echo "✅ billing.dat: $(wc -l < "$expect" | tr -d ' ') lines, every field in its place"
  exit 0
fi
want=$(wc -l < "$expect" | tr -d ' '); got=$(wc -l < billing.dat | tr -d ' ')
if [ "$got" -ne "$want" ]; then
  echo "❌ billing.dat has $got lines, expected $want (one per account, no header)"; exit 1
fi
if head -1 billing.dat | grep -q 'id'; then echo "❌ the header line must not be converted"; exit 1; fi
n=$(diff <(cat billing.dat) "$expect" | grep -m1 '^[0-9]' | sed 's/[^0-9].*//')
line=$(sed -n "${n}p" billing.dat)
wantlen=$(sed -n "${n}p" "$expect" | wc -c | tr -d ' ')
gotlen=$(printf '%s\n' "$line" | wc -c | tr -d ' ')
bad=$(grep -vcE '^ACCT[0-9]{6}\|.{12}\|[ 0-9]{7}\.[0-9]{2}$' billing.dat)
if [ "$bad" -gt 0 ]; then
  echo "❌ $bad line(s) do not have the shape ACCT000000|<12 chars>|<10 chars>, first one at line $n: '$line'"
else
  echo "❌ line $n is wrong: '$line' ($((gotlen - 1)) characters, expected $((wantlen - 1)))"
fi
exit 1
