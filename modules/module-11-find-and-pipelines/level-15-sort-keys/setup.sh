#!/bin/bash
# Capacity Review: a host inventory whose load column was written by an
# exporter that uses %g (so 0.01 comes out as 1e-02 and 12 as 1.2e+01), with
# hosts numbered without zero padding. New data on every setup.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

awk -v seed="$RANDOM$$" 'BEGIN {
  srand(seed)
  split("web app db cache worker", role, " ")
  split("ams1 fra1 lon2 par1", dc, " ")
  # a few load levels, each written in several ways (ties are on purpose)
  nl = split("0.003|3e-03|0.0030 0.01|1e-02|1e-2 0.04|4e-02|0.040 0.5|5e-01|0.50 0.75|7.5e-01|0.75 1.25|1.25|1.250 2|2|2.0 3.5|3.5|3.50 8|8|8.0 12|1.2e+01|12.0", lv, " ")
  # web9, web10 and web11 always share a datacenter and a load (written three
  # ways), so the host order inside a tie is visible.
  tdc = dc[int(rand() * 4) + 1]; tl = lv[int(rand() * nl) + 1]
  print "host dc rack load mem"
  for (r = 1; r <= 5; r++) {
    n = (role[r] == "web") ? 12 : 8 + int(rand() * 7)
    for (i = 1; i <= n; i++) {
      d = dc[int(rand() * 4) + 1]; split(lv[int(rand() * nl) + 1], form, "|"); f = int(rand() * 3) + 1
      if (role[r] == "web" && i >= 9 && i <= 11) { d = tdc; split(tl, form, "|"); f = i - 8 }
      rows[++k] = sprintf("%s%d %s r%02d %s %d", role[r], i, d, int(rand() * 12) + 1, form[f], 2 ^ (int(rand() * 4) + 4))
    }
  }
  for (i = k; i > 1; i--) { j = int(rand() * i) + 1; t = rows[i]; rows[i] = rows[j]; rows[j] = t }
  for (i = 1; i <= k; i++) print rows[i]
}' > inventory.txt

cksum < inventory.txt > .lm-state/inventory.sum
