#!/bin/bash
# Traffic Anomalies: 30 days of daily request counts for 7 hosts whose
# volumes differ by a factor of 100, with a few NaN and empty cells, a health
# checker with a perfectly constant count, a spike on a small host (invisible
# against a global baseline) and a drop on a big one. Regenerated until no
# z-score lies near the threshold. Random per setup.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

awk -v seed="$RANDOM$$" '
function gauss() { return sqrt(-2 * log(1 - rand())) * cos(6.283185307 * rand()) }
function isnum(s) { return s ~ /^-?[0-9]+(\.[0-9]+)?$/ }
BEGIN {
  srand(seed)
  nh = split("web-01 web-02 api-01 api-02 batch-01 mail-01 health-01", host, " ")
  split("118000 96000 41000 38500 6200 2100 1440", base, " ")
  split("5200 4100 1900 1700 380 140 0", noise, " ")
  for (try = 0; try < 200; try++) {
    delete v
    for (h = 1; h <= nh; h++) for (d = 1; d <= 30; d++)
      v[h, d] = (noise[h] == 0) ? base[h] : int(base[h] + noise[h] * gauss() + 0.5)
    # one spike on a small host, one outage-like drop on a big host, maybe one more
    small = 5 + int(rand() * 2); v[small, 3 + int(rand() * 25)] = int(base[small] + noise[small] * (8 + rand() * 3))
    big = 1 + int(rand() * 2);   v[big, 3 + int(rand() * 25)] = int(base[big] * (0.2 + rand() * 0.2))
    if (rand() < 0.6) { h = 3 + int(rand() * 2); v[h, 3 + int(rand() * 25)] = int(base[h] + noise[h] * (9 + rand() * 3)) }
    # gaps in the export
    for (k = 0; k < 5; k++) { h = 1 + int(rand() * 6); d = 1 + int(rand() * 30); v[h, d] = (k % 2) ? "NaN" : "" }
    ok = 1
    for (h = 1; h <= nh; h++) {
      n = 0; s = 0
      for (d = 1; d <= 30; d++) if (isnum(v[h, d])) { n++; s += v[h, d] }
      m = s / n; q = 0
      for (d = 1; d <= 30; d++) if (isnum(v[h, d])) q += (v[h, d] - m) ^ 2
      sd = sqrt(q / n); if (sd == 0) continue
      for (d = 1; d <= 30; d++) if (isnum(v[h, d])) { z = (v[h, d] - m) / sd; if (z < 0) z = -z; if (z > 2.6 && z < 3.4) ok = 0 }
    }
    if (ok) break
  }
  print "date,host,requests"
  for (d = 1; d <= 30; d++) {
    for (h = 1; h <= nh; h++) ord[h] = h
    for (h = nh; h > 1; h--) { j = 1 + int(rand() * h); t = ord[h]; ord[h] = ord[j]; ord[j] = t }
    for (k = 1; k <= nh; k++) printf "2026-10-%02d,%s,%s\n", d, host[ord[k]], v[ord[k], d]
  }
}' > requests.csv

cksum < requests.csv > .lm-state/requests.sum
