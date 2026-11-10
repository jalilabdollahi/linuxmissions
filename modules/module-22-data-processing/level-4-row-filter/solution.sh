#!/bin/bash
# Keep line 1, and every row whose 5th field lowercased is exactly "refunded"
# and whose 4th field, as a number, is above 100.
awk -F, 'NR == 1 || (tolower($5) == "refunded" && $4 > 100)' orders.csv > big_refunds.csv
cut -d, -f5 big_refunds.csv | sort | uniq -c
