#!/bin/bash
SANDBOX="$1"
FILE="$SANDBOX/totals.txt"

if [ ! -f "$FILE" ]; then
  echo "❌ totals.txt not found"
  exit 1
fi

EXPECTED='meals 19450.06
training 18655.62
software 18401.42
travel 17467.88
hardware 16815.02'

ACTUAL="$(tr -d '\r' < "$FILE" | awk 'NF { $1 = $1; print }')"
if [ "$ACTUAL" = "$EXPECTED" ]; then
  echo "✅ totals.txt has the exact total per category, largest first"
  exit 0
fi

if printf '%s\n' "$ACTUAL" | awk 'NF != 2 { bad = 1 } END { exit !bad }'; then
  echo "❌ some lines of totals.txt are not 'category total' (an empty category? the header or the TOTAL row?)"
  exit 1
fi
if printf '%s\n' "$ACTUAL" | grep -Eiq '^(category|total|amount) '; then
  echo "❌ totals.txt includes the header or the TOTAL footer row as if it were a category"
  exit 1
fi
n="$(printf '%s\n' "$ACTUAL" | grep -c .)"
if [ "$n" -ne 5 ]; then
  echo "❌ totals.txt has $n lines, but expenses.csv has 5 categories"
  exit 1
fi
if [ "$(printf '%s\n' "$ACTUAL" | sort)" = "$(printf '%s\n' "$EXPECTED" | sort)" ]; then
  echo "❌ the totals are right but not sorted from largest to smallest"
  exit 1
fi
if printf '%s\n' "$ACTUAL" | awk '{ print $2 }' | grep -Evq '^[0-9]+\.[0-9]{2}$'; then
  echo "❌ the totals must be written with exactly two decimals (cents), e.g. 123.40"
  exit 1
fi
echo "❌ the category totals in totals.txt do not match the sums of the amount column"
exit 1
