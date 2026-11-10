#!/bin/bash
# ETL Audit: source.csv (lowercase ids, some customer names quoted with a
# comma inside, amounts written as 87.5 / 1200 / 1234.56) against what the
# nightly load wrote, loaded.tsv (tab-separated, uppercase ids, amounts in
# cents, rows in load order). Some invoices were not loaded, the same number
# of rows were loaded twice (so the row counts match), and a few amounts
# changed on the way. Random per setup.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

awk -v seed="$RANDOM$$" '
function pick(a, n) { return a[int(rand() * n) + 1] }
function shown(c,   s) {
  if (c % 100 == 0 && rand() < 0.3) return sprintf("%d", c / 100)
  if (c % 10 == 0 && rand() < 0.6) return sprintf("%d.%d", int(c / 100), (c % 100) / 10)
  return sprintf("%d.%02d", int(c / 100), c % 100)
}
BEGIN {
  srand(seed)
  ncu = split("Northwind Traders|\"Acme, Inc.\"|Contoso Ltd|\"Smith, Jones & Partners\"|Fabrikam|Litware|\"Bauer, Klein GmbH\"|Tailspin Toys|Wide World Importers|Adventure Works", cust, "|")
  n = 380 + int(rand() * 80)
  for (i = 1; i <= n; i++) {
    do id = 4000 + int(rand() * 6000); while (id in used)
    used[id] = 1; ids[i] = id
    r = rand()
    cents[i] = (r < 0.15) ? 100 * (5 + int(rand() * 300)) : (r < 0.3) ? 10 * (100 + int(rand() * 9000)) : 199 + int(rand() * 250000)
    cu[i] = pick(cust, ncu)
  }
  # what goes wrong in the load
  nm = 2 + int(rand() * 3)
  for (k = 0; k < nm; k++) { do i = 1 + int(rand() * n); while (i in miss); miss[i] = 1 }
  for (k = 0; k < nm; k++) { do i = 1 + int(rand() * n); while ((i in miss) || (i in dup)); dup[i] = 1 }
  nc = 2 + int(rand() * 3)
  for (k = 0; k < nc; k++) { do i = 1 + int(rand() * n); while ((i in miss) || (i in dup) || (i in chg)); chg[i] = 1 }

  print "invoice_id,customer,amount" > "source.csv"
  for (i = 1; i <= n; i++) printf "inv-%06d,%s,%s\n", ids[i], cu[i], shown(cents[i]) > "source.csv"

  # load order: sorted by a load timestamp, not by the source order
  m = 0
  for (i = 1; i <= n; i++) {
    if (i in miss) continue
    c = cents[i]
    if (i in chg) c = (rand() < 0.5) ? c - int(c * (0.02 + rand() * 0.2)) - 1 : int(c * 1.1) + 1
    nm2 = cu[i]; gsub(/"/, "", nm2)
    row = sprintf("INV-%06d\t%s\t%d", ids[i], toupper(nm2), c)
    t[++m] = int(rand() * 7200); line[m] = row
    if (i in dup) { t[++m] = int(rand() * 7200); line[m] = row }
  }
  for (i = 2; i <= m; i++) { a = t[i]; b = line[i]; j = i - 1; while (j >= 1 && t[j] > a) { t[j + 1] = t[j]; line[j + 1] = line[j]; j-- } t[j + 1] = a; line[j + 1] = b }
  print "INVOICE_ID\tCUSTOMER\tAMOUNT_CENTS\tLOADED_AT" > "loaded.tsv"
  for (i = 1; i <= m; i++) printf "%s\t2026-11-10T02:%02d:%02dZ\n", line[i], int(t[i] / 120), int(t[i] / 2) % 60 > "loaded.tsv"
}'

cat source.csv loaded.tsv | cksum > .lm-state/inputs.sum
