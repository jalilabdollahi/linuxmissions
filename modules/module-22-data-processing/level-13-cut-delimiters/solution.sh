#!/bin/bash
# Keep the D records, cut out the three columns from LAYOUT.txt with a
# visible delimiter, then trim the name, quote it if it has a comma and turn
# the implied decimals into a real amount.
cat LAYOUT.txt
head -3 payroll.dat | cat -A
grep '^D' payroll.dat | cut -c2-7,8-37,46-54 --output-delimiter='|' \
  | awk -F'|' 'BEGIN { print "id,name,amount" }
      { sub(/ +$/, "", $2); if ($2 ~ /,/) $2 = "\"" $2 "\""; printf "%s,%s,%.2f\n", $1, $2, $3 / 100 }' > payroll.csv
head -5 payroll.csv
grep '"' payroll.csv
