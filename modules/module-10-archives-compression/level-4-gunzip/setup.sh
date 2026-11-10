#!/bin/bash
# Partner Drop: decompress inbox/*.csv.gz into import/ and keep the .gz files.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p inbox import .lm-state

# make_csv FILE HEADER KIND SEED: random rows, different shape per export
make_csv() {
  awk -v hdr="$2" -v kind="$3" -v seed="$4" 'BEGIN {
    srand(seed); print hdr
    n = 40 + int(rand() * 160)
    for (i = 1; i <= n; i++) {
      if (kind == "orders")   printf "SO-%06d,%s,%d,%.2f\n", 100000 + int(rand()*900000), (rand() < 0.5 ? "DE" : "NL"), 1 + int(rand()*9), rand()*400
      if (kind == "returns")  printf "RT-%05d,SO-%06d,%s\n", i, 100000 + int(rand()*900000), (rand() < 0.3 ? "damaged" : "unwanted")
      if (kind == "stock")    printf "SKU-%04d,%d,WH%d\n", int(rand()*10000), int(rand()*500), 1 + int(rand()*3)
      if (kind == "carriers") printf "%s,%d,%.1f\n", (rand() < 0.5 ? "DHL" : "PostNL"), int(rand()*48), rand()*100
    }
  }' > "$1"
}

make_csv inbox/orders-2026-11-09.csv  "order_id,country,qty,amount" orders   "$RANDOM"
make_csv inbox/orders-2026-11-10.csv  "order_id,country,qty,amount" orders   "$RANDOM"
make_csv inbox/returns-2026-11.csv    "return_id,order_id,reason"   returns  "$RANDOM"
make_csv inbox/stock-levels.csv       "sku,on_hand,warehouse"       stock    "$RANDOM"
make_csv inbox/carrier-sla.csv        "carrier,hours,on_time_pct"   carriers "$RANDOM"

for f in inbox/*.csv; do
  echo "$(basename "$f") $(cksum < "$f")" >> .lm-state/csv.sums
  gzip -9 "$f"
done
printf 'Drop 2026-11-10 from NordFreight: 5 files, gzip, UTF-8, comma separated.\n' > inbox/MANIFEST.txt
for f in inbox/*; do
  echo "$(basename "$f") $(cksum < "$f")" >> .lm-state/inbox.sums
done
