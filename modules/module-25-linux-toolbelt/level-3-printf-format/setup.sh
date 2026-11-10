#!/bin/bash
# accounts.csv: header + ~60 accounts with names of every length (some contain
# spaces, some are over 12 characters) and amounts of different shapes (whole
# numbers, one decimal, two decimals, thousands).
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

awk -v seed="$RANDOM$$" '
BEGIN {
  srand(seed)
  split("Acme Corp|Bluebird Bakery|Cedar Hill Dental|Delta Freight and Logistics|Eastside Florist|Fjord Outfitters|Granite Works|Harbor Light Cafe|Iron Oak Joinery|Juniper Tech|Kestrel Aviation Services|Lumen Studio|Maple Street Books|Northwind Traders|Orchid House|Pioneer Plumbing|Quill and Ink|Redwood Capital Partners|Summit Climbing|Tidewater Marine|Union Print|Vega Labs|Willow Creek Farm|Xylo|Yardley Hardware|Zenith Optics", nm, "|")
  print "id,name,amount"
  id = 100 + int(rand() * 900)
  n = 55 + int(rand() * 15)
  for (i = 0; i < n; i++) {
    id += 1 + int(rand() * 40)
    r = rand()
    if (r < 0.2) amt = sprintf("%d", 1 + int(rand() * 900))
    else if (r < 0.4) amt = sprintf("%.1f", rand() * 5000)
    else amt = sprintf("%.2f", rand() * 20000)
    if (i == 3) amt = "7"
    if (i == 5) amt = "0.5"
    print id "," nm[1 + int(rand() * 26)] "," amt
  }
}' > accounts.csv
cksum < accounts.csv > .lm-state/accounts.sum
