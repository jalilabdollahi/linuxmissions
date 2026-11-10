#!/bin/bash
# Orders By Region: one big CSV with the region in column 3; region names
# contain "/" and spaces, every region comes back many times, and by_region/
# still holds last month's files (one region has since been merged away).
# Random per setup.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state by_region

awk -v seed="$RANDOM$$" '
BEGIN {
  srand(seed)
  nr = split("EU/West|EU/North|EU/East|Asia Pacific|North America|LATAM|Middle East/Africa", reg, "|")
  split("4 3 2 3 4 2 1", weight, " ")
  for (i = 1; i <= nr; i++) for (k = 0; k < weight[i]; k++) pool[++np] = reg[i]
  nc = split("Hagen Werkzeuge GmbH|Sato Electronics|Polar Pine Oy|Andes Cafe SA|Maple Leaf Supply|Desert Rose Trading|Vistula Print|Kiwi Outdoor Ltd|Gulf Marine LLC|Rio Verde Ltda|Tatra Foods|Nordic Light AB|Lotus Textiles|Prairie Seeds Inc", cust, "|")
  print "order_id,order_date,region,customer,amount_eur"
  n = 520 + int(rand() * 160)
  for (i = 1; i <= n; i++) {
    r = pool[int(rand() * np) + 1]
    if (i <= nr) r = reg[(i * 3) % nr + 1]
    printf "ORD-%05d,2026-10-%02d,%s,%s,%.2f\n", 31000 + i, 1 + int((i - 1) * 31 / n), r, cust[int(rand() * nc) + 1], 40 + rand() * 4000
  }
}' > all_orders.csv

# last month's split, never cleaned up
printf 'order_id,order_date,region,customer,amount_eur\nORD-30412,2026-09-03,EU/West,Hagen Werkzeuge GmbH,812.40\nORD-30977,2026-09-28,EU/West,Polar Pine Oy,96.10\n' > by_region/EU-West.csv
printf 'order_id,order_date,region,customer,amount_eur\nORD-30533,2026-09-11,Benelux,Vistula Print,1402.75\n' > by_region/Benelux.csv

cksum < all_orders.csv > .lm-state/orders.sum
