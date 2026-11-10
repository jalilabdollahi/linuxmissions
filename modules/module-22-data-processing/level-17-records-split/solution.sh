#!/bin/bash
# Start from an empty directory, then let awk write every row to the file of
# its region, printing the header only the first time a file is opened.
cut -d, -f3 all_orders.csv | sort | uniq -c
ls by_region
rm -f by_region/*
awk -F, 'NR == 1 { header = $0; next }
  { f = $3; gsub("/", "-", f); gsub(" ", "_", f); f = "by_region/" f ".csv"
    if (!(f in seen)) { print header > f; seen[f] = 1 }
    print > f }' all_orders.csv
wc -l by_region/*
