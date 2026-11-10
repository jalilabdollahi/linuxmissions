#!/bin/bash
# CSVs Only, Please: CSVs at three depths, decoys, __MACOSX junk, and a newer
# import/customers.csv that must not be overwritten.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p import .lm-state
B=.lm-state/build
mkdir -p "$B/export/2026/q3" "$B/export/img" "$B/__MACOSX/export/2026/q3"

csv() {  # csv HEADER SEED: random rows
  awk -v h="$1" -v seed="$2" 'BEGIN { srand(seed); print h; n = 20 + int(rand()*80)
    for (i = 1; i <= n; i++) printf "%d,C%05d,%.2f,%s\n", i, int(rand()*99999), rand()*900, (rand() < 0.5 ? "EUR" : "CHF") }'
}
csv "id,customer,balance,currency"   "$RANDOM" > "$B/export/customers.csv"
csv "id,contact,score,currency"      "$RANDOM" > "$B/contacts.csv"
csv "id,order,total,currency"        "$RANDOM" > "$B/export/orders.csv"
csv "id,invoice,amount,currency"     "$RANDOM" > "$B/export/2026/q3/invoices.csv"
csv "id,refund,amount,currency"      "$RANDOM" > "$B/export/2026/q3/refunds.csv"
printf 'All files are UTF-8, comma separated.\nColumns are described in schema.json.\n' > "$B/export/README.csv.txt"
printf '{"customers": ["id", "customer", "balance", "currency"]}\n' > "$B/export/schema.json"
printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR' > "$B/export/img/logo.png"
for p in contacts.csv export/orders.csv export/2026/q3/invoices.csv; do
  mkdir -p "$B/__MACOSX/$(dirname "$p")"
  printf '\x00\x05\x16\x07\x00\x02\x00\x00Mac OS X        \x00\x02' > "$B/__MACOSX/$(dirname "$p")/._$(basename "$p")"
done
printf 'Bud1\x00\x00\x10\x00' > "$B/export/.DS_Store"
find "$B" -exec touch -t 202611010815 {} +
(cd "$B" && zip -q -r ../../upload.zip contacts.csv export __MACOSX)

# Yesterday's hand-corrected customers.csv (newer than the zip's copy).
{ head -1 "$B/export/customers.csv"; tail -n +2 "$B/export/customers.csv" | sed 's/,CHF$/,EUR/'; echo "999,C00000,0.00,EUR"; } > import/customers.csv
touch -t 202611091640 import/customers.csv
cksum < import/customers.csv > .lm-state/customers.sum
cksum < upload.zip > .lm-state/zip.sum
rm -rf "$B"
