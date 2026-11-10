#!/bin/bash
# Order export with a status column in mixed spellings: refunded / Refunded /
# REFUNDED, but also partially_refunded and refund_pending, which a plain
# grep for "refunded" (or "refund") catches too. Amounts sit around the 100.00
# limit on purpose, including exactly 100.00.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

awk -v seed="$RANDOM$$" '
BEGIN {
  srand(seed)
  nc = split("dkowalski amira.h jsmith88 lena_b ofo.ade petra.n raj_k sofia.m tom_w yuki.t zane77 ewa.l", cust, " ")
  ns = split("paid paid paid shipped shipped delivered cancelled refunded Refunded REFUNDED partially_refunded Partially_Refunded refund_pending", stat, " ")
  ne = split("100.00 99.99 100.01 100.00 1000.00 100.50", edge, " ")
  print "order_id,customer,date,amount,status"
  n = 380 + int(rand() * 120)
  id = 70000 + int(rand() * 9000)
  for (i = 1; i <= n; i++) {
    s = stat[int(rand() * ns) + 1]
    r = rand()
    if (r < 0.12)      a = edge[int(rand() * ne) + 1]
    else if (r < 0.2)  a = sprintf("%.2f", 1000 + rand() * 2500)
    else               a = sprintf("%.2f", 5 + rand() * 300)
    printf "%d,%s,2026-%02d-%02d,%s,%s\n", id, cust[int(rand() * nc) + 1], 7 + int((i - 1) * 3 / n), 1 + int(rand() * 28), a, s
    id += 1 + int(rand() * 4)
  }
  # make sure every trap is present at least once
  printf "%d,%s,2026-09-29,100.00,refunded\n", id + 1, cust[1]
  printf "%d,%s,2026-09-29,240.00,partially_refunded\n", id + 3, cust[2]
  printf "%d,%s,2026-09-30,1250.00,REFUNDED\n", id + 4, cust[3]
  printf "%d,%s,2026-09-30,180.25,Refunded\n", id + 6, cust[4]
}' > orders.csv

cksum < orders.csv > .lm-state/orders.sum
