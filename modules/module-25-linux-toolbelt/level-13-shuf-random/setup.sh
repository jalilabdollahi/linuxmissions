#!/bin/bash
# tx.csv: a header and 300-500 transactions with random ids and amounts.
# seed.bin: 4 KB of random bytes that is the only source of randomness allowed.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state
rows=$((300 + RANDOM % 201))
awk -v n="$rows" -v s="$RANDOM$$" 'BEGIN {
  srand(s)
  split("ACME Globex Initech Umbrella Hooli Stark Wayne Wonka Soylent Tyrell", co, " ")
  split("EUR USD GBP CHF", cur, " ")
  print "tx_id,date,customer,currency,amount"
  for (i = 1; i <= n; i++)
    printf "TX%05d,2026-%02d-%02d,%s,%s,%.2f\n", 10000 + i * 3 + int(rand() * 3), 7 + int(rand() * 3), 1 + int(rand() * 28), co[1 + int(rand() * 10)], cur[1 + int(rand() * 4)], 5 + rand() * 4000
}' > tx.csv
head -c 4096 /dev/urandom > seed.bin
cp tx.csv .lm-state/tx.csv
cp seed.bin .lm-state/seed.bin
