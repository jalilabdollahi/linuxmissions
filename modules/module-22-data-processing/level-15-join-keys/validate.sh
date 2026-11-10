#!/bin/bash
# customer_totals.csv = header + every customer of customers.csv with the
# number and the sum of their orders (0 and 0.00 when none), ordered by
# customer_id as a number. Orders of unknown customers are not reported.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -s .lm-state/inputs.sum ] || [ "$(cat customers.csv orders.csv 2>/dev/null | cksum)" != "$(cat .lm-state/inputs.sum)" ]; then
  echo "❌ customers.csv or orders.csv was changed or removed; type 'reset' to restore them"
  exit 1
fi
if [ ! -f customer_totals.csv ]; then
  echo "❌ customer_totals.csv does not exist yet"
  exit 1
fi

# Hash join in awk, amounts summed in cents.
EXPECTED=$(awk -F, '
  FNR == 1 { next }
  FILENAME == "orders.csv" { split($3, a, "."); cnt[$4]++; cents[$4] += a[1] * 100 + a[2]; next }
  { printf "%s,%s,%d,%d.%02d\n", $1, $2, cnt[$1], int(cents[$1] / 100), cents[$1] % 100 }' orders.csv customers.csv | sort -t, -k1,1n)
NC=$(printf '%s\n' "$EXPECTED" | wc -l | tr -d ' ')
GOT=$(tr -d '\r' < customer_totals.csv | grep -v '^$')

if [ "$(printf '%s\n' "$GOT" | head -n 1)" != "customer_id,name,orders,total" ]; then
  echo "❌ the first line of customer_totals.csv must be the header customer_id,name,orders,total"
  exit 1
fi
BODY=$(printf '%s\n' "$GOT" | tail -n +2)
if [ "$BODY" = "$EXPECTED" ]; then
  echo "✅ customer_totals.csv has all $NC customers with their order count and total, idle customers included"
  exit 0
fi

if printf '%s\n' "$BODY" | awk -F, 'NF != 4 { f = 1 } END { exit !f }'; then
  echo "❌ every row must have 4 fields: customer_id,name,orders,total"
  exit 1
fi
if printf '%s\n' "$BODY" | awk -F, '$1 >= 9000 { f = 1 } END { exit !f }'; then
  echo "❌ customer_totals.csv lists customer ids that are not in customers.csv (orders of deleted accounts); report only the customers of customers.csv"
  exit 1
fi
ng=$(printf '%s\n' "$BODY" | grep -c .)
if [ "$ng" -lt "$NC" ]; then
  idle_want=$(printf '%s\n' "$EXPECTED" | grep -c ',0,0\.00$')
  missing=$(comm -23 <(printf '%s\n' "$EXPECTED" | cut -d, -f1 | sort) <(printf '%s\n' "$BODY" | cut -d, -f1 | sort))
  busy_missing=$(printf '%s\n' "$EXPECTED" | awk -F, -v m="$(printf '%s ' $missing)" 'BEGIN { split(m, x, " "); for (i in x) w[x[i]] = 1 } ($1 in w) && $3 > 0 { c++ } END { print c + 0 }')
  if [ "$busy_missing" -gt 0 ]; then
    echo "❌ customer_totals.csv has $ng customers, expected $NC; even customers with orders are missing. join only pairs lines when both inputs are sorted the way join compares (as text, not with sort -n); it skips the rest"
  else
    echo "❌ customer_totals.csv has $ng customers, expected $NC; the $idle_want customers without orders must be listed too, with 0 orders and 0.00"
  fi
  exit 1
fi
if [ "$ng" -gt "$NC" ]; then
  echo "❌ customer_totals.csv has $ng customers, but customers.csv has only $NC"
  exit 1
fi
if [ "$(printf '%s\n' "$BODY" | sort)" = "$(printf '%s\n' "$EXPECTED" | sort)" ]; then
  echo "❌ the rows are right but must be ordered by customer_id as a number (9 before 10 before 100)"
  exit 1
fi
idle_want=$(printf '%s\n' "$EXPECTED" | grep -c ',0,0\.00$')
idle_got=$(printf '%s\n' "$BODY" | awk -F, '$3 == 0 || $3 == "" || $3 == "NONE" { c++ } END { print c + 0 }')
if [ "$idle_got" -gt "$idle_want" ]; then
  echo "❌ $idle_got customers have no orders in your file, but only $idle_want really have none: join missed partners. It only pairs lines when both inputs are sorted the way join compares (as text, not with sort -n)"
  exit 1
fi
if printf '%s\n' "$BODY" | awk -F, '$4 !~ /^[0-9]+\.[0-9][0-9]$/ { f = 1 } END { exit !f }'; then
  echo "❌ every total must have exactly two decimals, also for customers without orders (0.00)"
  exit 1
fi
bad=$(awk -F, 'NR == FNR { w[$1] = $0; next } w[$1] != $0 { print $1; exit }' <(printf '%s\n' "$EXPECTED") <(printf '%s\n' "$BODY"))
echo "❌ the row of customer ${bad:-?} is not right: name from customers.csv, then the count and the sum of its orders in orders.csv"
exit 1
