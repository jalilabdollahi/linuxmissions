# Expense Report

## What you practiced
Awk arrays let you aggregate data without leaving the shell. This is a classic pattern for quick reporting over CSV-like files.

## Commands to remember
```bash
awk -F, 'NR>1 {totals[$1]+=$2} END {for (k in totals) print k, totals[k]}' expenses.csv
sort -k2,2nr
```
