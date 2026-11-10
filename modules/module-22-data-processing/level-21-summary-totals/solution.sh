#!/bin/bash
# Group the rows (stable sort keeps the ledger order inside a team), then one
# awk pass that prints a subtotal whenever the team or department changes.
head -5 ledger.csv
grep '"' ledger.csv | head -3
tail -n +2 ledger.csv | sort -s -t, -k1,1 -k2,2 | awk -F, '
  function amount(   a) { a = $5 $6; gsub(/[",]/, "", a); if (a ~ /^\(/) { gsub(/[()]/, "", a); a = -a } return a + 0 }
  NR > 1 && ($1 != dep || $2 != team) { printf "%s\t%s\tTEAM TOTAL\t\t%.2f\n", dep, team, tsum; tsum = 0 }
  NR > 1 && $1 != dep { printf "%s\t\tDEPARTMENT TOTAL\t\t%.2f\n", dep, dsum; dsum = 0 }
  { a = amount(); printf "%s\t%s\t%s\t%s\t%.2f\n", $1, $2, $3, $4, a; dep = $1; team = $2; tsum += a; dsum += a; gsum += a }
  END { printf "%s\t%s\tTEAM TOTAL\t\t%.2f\n", dep, team, tsum; printf "%s\t\tDEPARTMENT TOTAL\t\t%.2f\n", dep, dsum; printf "\t\tGRAND TOTAL\t\t%.2f\n", gsum }' > report.tsv
head -20 report.tsv
tail -3 report.tsv
