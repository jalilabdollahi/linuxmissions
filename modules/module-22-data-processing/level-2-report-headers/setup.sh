#!/bin/bash
# Three monthly invoice exports with the same header. feb.csv was saved by an
# editor that leaves out the newline after the last line, so a plain
# concatenation glues its last invoice to the next file's first line.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

awk -v seed="$RANDOM$$" '
BEGIN {
  srand(seed)
  nc = split("Nordwind GmbH|Atlas Freight|Brightside Dental|Casa Verde|Duna Print|Eastgate Hotels|Fernhill School|Golden Crust Bakery|Harbor IT|Iris Optics|Kestrel Air|Lumen Studios", cust, "|")
  split("31 28 31", days, " ")
  split("jan feb mar", file, " ")
  inv = 1000 + int(rand() * 8000)
  for (m = 1; m <= 3; m++) {
    out = file[m] ".csv"
    printf "date,invoice,customer,amount,currency\n" > out
    rows = 40 + int(rand() * 40)
    for (r = 1; r <= rows; r++) {
      d = 1 + int((r - 1) * days[m] / rows)
      cur = (rand() < 0.8) ? "EUR" : "USD"
      line = sprintf("2026-%02d-%02d,INV-2026-%05d,%s,%.2f,%s", m, d, inv++, cust[int(rand() * nc) + 1], 20 + rand() * 4900, cur)
      if (m == 2 && r == rows) printf "%s", line > out
      else print line > out
    }
    close(out)
  }
}'

cat jan.csv feb.csv mar.csv | cksum > .lm-state/months.sum
