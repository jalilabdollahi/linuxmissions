#!/bin/bash
# q1.csv = header once + data rows of jan, feb, mar in that order.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -s .lm-state/months.sum ] || [ "$(cat jan.csv feb.csv mar.csv 2>/dev/null | cksum)" != "$(cat .lm-state/months.sum)" ]; then
  echo "❌ jan.csv, feb.csv or mar.csv was changed or removed; type 'reset' to restore them"
  exit 1
fi
if [ ! -f q1.csv ]; then
  echo "❌ q1.csv does not exist yet"
  exit 1
fi

HEADER="date,invoice,customer,amount,currency"
EXPECTED=$(awk 'NR == 1 || FNR > 1' jan.csv feb.csv mar.csv)
GOT=$(tr -d '\r' < q1.csv)
if [ "$GOT" = "$EXPECTED" ]; then
  echo "✅ q1.csv: one header and all $(($(printf '%s\n' "$EXPECTED" | wc -l) - 1)) invoices of January to March, in order"
  exit 0
fi

if [ -z "$GOT" ]; then echo "❌ q1.csv is empty"; exit 1; fi
headers=$(printf '%s\n' "$GOT" | grep -c "^$HEADER")
if [ "$headers" -gt 1 ]; then
  echo "❌ q1.csv has the header line $headers times; it should appear once, at the top"
  exit 1
fi
if [ "$(printf '%s\n' "$GOT" | head -n 1)" != "$HEADER" ]; then
  echo "❌ the first line of q1.csv must be the header: $HEADER"
  exit 1
fi
glued=$(printf '%s\n' "$GOT" | awk -F, 'NF > 5 { print NR; exit }')
if [ -n "$glued" ]; then
  echo "❌ line $glued of q1.csv holds two rows glued together; check how each monthly file ends (tail -c 20 feb.csv | od -c)"
  exit 1
fi
want_rows=$(printf '%s\n' "$EXPECTED" | wc -l | tr -d ' ')
got_rows=$(printf '%s\n' "$GOT" | grep -c .)
if [ "$got_rows" -ne "$want_rows" ]; then
  echo "❌ q1.csv has $got_rows lines, expected $want_rows (one header plus every invoice of the three months)"
  exit 1
fi
if [ "$(printf '%s\n' "$GOT" | sort)" = "$(printf '%s\n' "$EXPECTED" | sort)" ]; then
  echo "❌ all invoices are there, but not in month order: January's rows first, then February's, then March's (a *.csv glob lists feb before jan)"
  exit 1
fi
echo "❌ q1.csv has the right number of lines, but some rows differ from the monthly files; copy the data rows unchanged"
exit 1
