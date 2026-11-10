#!/bin/bash
# Ledger Rollup: October's ledger in date order, departments and teams mixed.
# Amounts as the accounting tool writes them: 87.20, "1,234.50" (quoted
# because of the thousands separator), (45.00) and "(1,045.00)" for refunds.
# Random per setup.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

awk -v seed="$RANDOM$$" '
function money(c,   neg, s, w) {
  neg = (c < 0); if (neg) c = -c
  w = int(c / 100)
  s = (w >= 1000) ? sprintf("%d,%03d.%02d", int(w / 1000), w % 1000, c % 100) : sprintf("%d.%02d", w, c % 100)
  if (neg) s = "(" s ")"
  return (s ~ /,/) ? "\"" s "\"" : s
}
BEGIN {
  srand(seed)
  nt = split("Engineering/Backend Engineering/Data Engineering/Mobile Engineering/Platform Finance/Accounting Finance/Payroll Finance/Procurement Marketing/Brand Marketing/Events Marketing/Growth Operations/Facilities Operations/Logistics", unit, " ")
  nd = split("Cloud invoice|Contractor hours|Software licence|Conference tickets|Office supplies|Travel reimbursement|Hardware order|Agency retainer|Training course|Catering|Courier service|Ad campaign", desc, "|")
  print "department,team,date,description,amount"
  n = 150 + int(rand() * 50)
  for (i = 1; i <= n; i++) {
    u = (i <= nt) ? unit[i] : unit[int(rand() * nt) + 1]
    split(u, p, "/")
    r = rand()
    if (r < 0.12) c = -(500 + int(rand() * 20000))          # refunds and credit notes
    else if (r < 0.40) c = 100000 + int(rand() * 4500000)  # 1,000.00 and more
    else c = 300 + int(rand() * 99000)
    d[i] = sprintf("2026-10-%02d", 1 + int((i - 1) * 31 / n))
    line[i] = p[1] "," p[2] "," d[i] "," desc[int(rand() * nd) + 1] "," money(c)
  }
  # date order, the first rows of each team scattered over the month
  for (i = n; i > 1; i--) { j = int(rand() * i) + 1; t = line[i]; line[i] = line[j]; line[j] = t }
  for (i = 1; i <= n; i++) { split(line[i], f, ","); key[i] = f[3] }
  for (i = 2; i <= n; i++) { t = line[i]; k = key[i]; j = i - 1; while (j >= 1 && key[j] > k) { line[j + 1] = line[j]; key[j + 1] = key[j]; j-- } line[j + 1] = t; key[j + 1] = k }
  for (i = 1; i <= n; i++) print line[i]
}' > ledger.csv

cksum < ledger.csv > .lm-state/ledger.sum
