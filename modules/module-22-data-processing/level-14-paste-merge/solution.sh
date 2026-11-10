#!/bin/bash
# Remove the CRs, drop the separator lines, glue every 4 lines into one row,
# then build the one-line manifest from the first column.
cat -A scan_dump.txt | head -12
tr -d '\r' < scan_dump.txt | grep -vx -- '--' | paste - - - - > rows.tmp
{ printf 'parcel\tweight_kg\tpostcode\tdock\n'; cat rows.tmp; } > parcels.tsv
cut -f1 rows.tmp | paste -sd, - > manifest.txt
rm rows.tmp
head -3 parcels.tsv
