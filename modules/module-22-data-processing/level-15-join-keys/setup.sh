#!/bin/bash
# Customer Totals: customers.csv (key in column 1) and orders.csv (key in
# column 4), both with headers and in no particular order. Numeric ids of 1
# to 4 digits, so a numeric sort and join's text order disagree. Some
# customers have no orders; a few orders belong to deleted test accounts
# that are not in customers.csv. Random per setup.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

awk -v seed="$RANDOM$$" '
BEGIN {
  srand(seed)
  na = split("Nordwind Blue Fjord Kestrel Alder Copper Granite Harbour Juniper Lantern Meridian Northgate Oakfield Pinecrest Quarry Riverside Saltmarsh Thornbury Upland Vale Westbrook Yarrow Zenith Amber Birch Cedar", adj, " ")
  nb = split("Trading Logistics Foods Systems Dental Bakery Studios Hardware Analytics Clinic Outfitters Print", noun, " ")
  nc = split("NO SE DK FI DE NL", cty, " ")
  n = 70 + int(rand() * 25)
  print "customer_id,name,country,since" > "customers.csv"
  for (i = 1; i <= n; i++) {
    # ids of different lengths: 1, 2, 3 and 4 digits
    do {
      r = (i <= 3) ? 0.2 : rand()
      id = (r < 0.08) ? 1 + int(rand() * 9) : (r < 0.3) ? 10 + int(rand() * 90) : (r < 0.65) ? 100 + int(rand() * 900) : 1000 + int(rand() * 3000)
    } while (id in used)
    used[id] = 1; ids[i] = id
    do nm = adj[int(rand() * na) + 1] " " noun[int(rand() * nb) + 1]; while (nm in names)
    names[nm] = 1
    printf "%d,%s,%s,20%02d-%02d-%02d\n", id, nm, cty[int(rand() * nc) + 1], 15 + int(rand() * 11), 1 + int(rand() * 12), 1 + int(rand() * 28) > "customers.csv"
  }
  # about one customer in six never ordered
  for (i = 1; i <= n; i++) if (rand() < 0.17) idle[i] = 1
  idle[1 + int(rand() * n)] = 1
  # the largest two-digit customer never ordered: right before the 3-digit ids
  for (i = 1; i <= n; i++) if (ids[i] < 100 && (big == "" || ids[i] > ids[big])) big = i
  idle[big] = 1
  print "order_id,date,amount,customer_id" > "orders.csv"
  no = 380 + int(rand() * 120)
  for (k = 1; k <= no; k++) {
    if (rand() < 0.02) c = 9000 + int(rand() * 900)          # deleted test account
    else { do i = 1 + int(rand() * n); while (i in idle); c = ids[i] }
    cents = (rand() < 0.1) ? 50000 + int(rand() * 300000) : 900 + int(rand() * 45000)
    printf "SO-%06d,2026-%02d-%02d,%d.%02d,%d\n", 104000 + k * 3 + int(rand() * 3), 1 + int(rand() * 10), 1 + int(rand() * 28), int(cents / 100), cents % 100, c > "orders.csv"
  }
}'

cat customers.csv orders.csv | cksum > .lm-state/inputs.sum
