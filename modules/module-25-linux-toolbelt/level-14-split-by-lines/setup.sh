#!/bin/bash
# customers.csv: header + exactly 23,417 data rows with random names and cities.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state
awk -v s="$RANDOM$$" 'BEGIN {
  srand(s)
  split("Alder Birch Cole Dunn Evans Frost Grant Hale Ito Jain Khan Lowe Moss Nair Ortiz Pike Quinn Reyes Shaw Tran", ln, " ")
  split("Ana Ben Chloe Dev Elif Finn Gita Hugo Iris Jon Kai Lena Maya Noor Omar", fn, " ")
  split("Oslo Lyon Porto Graz Turin Cork Bonn Riga Brno Metz", city, " ")
  print "id,first,last,city,plan"
  for (i = 1; i <= 23417; i++)
    printf "%d,%s,%s,%s,%s\n", 700000 + i, fn[1 + int(rand() * 15)], ln[1 + int(rand() * 20)], city[1 + int(rand() * 10)], (rand() < 0.3 ? "pro" : "free")
}' > customers.csv
cp customers.csv .lm-state/customers.csv
