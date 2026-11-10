#!/bin/bash
# Expense Report: 200 expense rows (date,employee,category,amount with cents),
# a header, a blank line and a TOTAL footer row from the finance export.
SANDBOX="$1"

awk 'BEGIN {
  split("travel software meals hardware training", cat, " ")
  split("alice bob carol dave erin frank grace", emp, " ")
  print "date,employee,category,amount"
  total = 0
  for (i = 1; i <= 200; i++) {
    cents = (i * 7919 + i * i * 13) % 90000 + 1000
    total += cents
    printf "2024-03-%02d,%s,%s,%d.%02d\n", (i % 28) + 1, emp[(i * 3) % 7 + 1], cat[(i * 7 + int(i / 3)) % 5 + 1], int(cents / 100), cents % 100
  }
  print ""
  printf "TOTAL,,,%d.%02d\n", int(total / 100), total % 100
}' > "$SANDBOX/expenses.csv"
