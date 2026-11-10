#!/bin/bash
# big_refunds.csv = header + rows with lower(status) == "refunded" and amount > 100.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -s .lm-state/orders.sum ] || [ "$(cksum < orders.csv 2>/dev/null)" != "$(cat .lm-state/orders.sum)" ]; then
  echo "❌ orders.csv was changed or removed; type 'reset' to restore it"
  exit 1
fi
if [ ! -f big_refunds.csv ]; then
  echo "❌ big_refunds.csv does not exist yet"
  exit 1
fi

EXPECTED=$(awk -F, 'NR == 1 || (tolower($5) == "refunded" && $4 + 0 > 100)' orders.csv)
GOT=$(tr -d '\r' < big_refunds.csv | sed '/^[[:space:]]*$/d')
if [ "$GOT" = "$EXPECTED" ]; then
  echo "✅ big_refunds.csv: the header and all $(($(printf '%s\n' "$EXPECTED" | wc -l) - 1)) refunds over 100.00"
  exit 0
fi

if [ -z "$GOT" ]; then echo "❌ big_refunds.csv is empty"; exit 1; fi
if [ "$(printf '%s\n' "$GOT" | head -n 1)" != "order_id,customer,date,amount,status" ]; then
  echo "❌ the first line of big_refunds.csv must be the header of orders.csv"
  exit 1
fi
# Classify every data row the player wrote.
msg=$(printf '%s\n' "$GOT" | awk -F, '
  NR == 1 { next }
  { s = tolower($5) }
  s != "refunded" && s ~ /refund/ { print "❌ big_refunds.csv includes a " $5 " order (" $1 "): only the status refunded counts"; exit }
  s != "refunded" { print "❌ big_refunds.csv includes order " $1 " with status " $5 ", which is not a refund"; exit }
  $4 + 0 == 100 { print "❌ big_refunds.csv includes order " $1 " for exactly 100.00; the limit is more than 100.00"; exit }
  $4 + 0 < 100 { print "❌ big_refunds.csv includes order " $1 " for " $4 ", which is not more than 100.00"; exit }')
if [ -n "$msg" ]; then echo "$msg"; exit 1; fi
missing=$(printf '%s\n' "$EXPECTED" | grep -vxF -f <(printf '%s\n' "$GOT") | head -n 1)
if [ -n "$missing" ]; then
  st=$(printf '%s\n' "$missing" | cut -d, -f5)
  if [ "$st" != "refunded" ]; then
    echo "❌ big_refunds.csv misses refunds whose status is written $st; the status counts in any letter case"
  else
    echo "❌ big_refunds.csv misses some refunds over 100.00 (for example order $(printf '%s\n' "$missing" | cut -d, -f1)); compare the amount as a number"
  fi
  exit 1
fi
echo "❌ big_refunds.csv has the right rows, but not exactly once each in the order of orders.csv, or a row was changed"
exit 1
