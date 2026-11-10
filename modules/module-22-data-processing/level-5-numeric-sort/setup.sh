#!/bin/bash
# Sensor readings in mixed number formats. The highest values are mostly
# written in scientific notation (sort -n reads 1.2e3 as 1.2), and short
# integers like 9 and 12 make a text sort wrong. All values are distinct so
# the top 10 has exactly one correct order.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

awk -v seed="$RANDOM$$" '
function fresh(v) { while (v in seen) v = v + 0.01; seen[v] = 1; return v }
BEGIN {
  srand(seed)
  ns = split("boiler-1 boiler-2 kiln-A kiln-B dryer-3 chiller-1 press-7 oven-2", sensor, " ")
  print "sensor,timestamp,value"
  n = 450 + int(rand() * 150)
  # the spikes: big values in scientific notation, on random rows
  # (mantissa e exponent, e or E): 4.0e2 .. 9.95e2 and 1.0e3 .. 2.95e3
  nbig = 5 + int(rand() * 4)
  for (k = 1; k <= nbig; k++) {
    do {
      if (rand() < 0.5) { m = 4 + int(rand() * 120) / 20; x = 2 } else { m = 1 + int(rand() * 40) / 20; x = 3 }
    } while ((m * 10 ^ x) in seen)
    seen[m * 10 ^ x] = 1
    do pos = int(rand() * n) + 1; while (pos in at)
    at[pos] = m ((rand() < 0.7) ? "e" : "E") x
  }
  for (i = 1; i <= n; i++) {
    t = sprintf("2026-11-0%dT%02d:%02d:%02dZ", 3 + int(i * 5 / n), int(rand() * 24), int(rand() * 60), int(rand() * 60))
    if (i in at) { v = at[i] }
    else {
      r = rand()
      if (r < 0.25)      v = fresh(int(rand() * 40) - 5)
      else if (r < 0.35) v = sprintf("%.2e", fresh(int(rand() * 4000) / 100 + 0.001))
      else if (r < 0.45) v = sprintf("%.1f", fresh(-int(rand() * 400) / 10))
      else               v = sprintf("%.2f", fresh(int(rand() * 38000) / 100))
    }
    printf "%s,%s,%s\n", sensor[int(rand() * ns) + 1], t, v
  }
}' > readings.csv

cksum < readings.csv > .lm-state/readings.sum
