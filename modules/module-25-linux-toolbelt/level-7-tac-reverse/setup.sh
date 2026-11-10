#!/bin/bash
# CHANGES: 10-16 release blocks, each starting with a "----" line, then a version
# header and 2-6 bullet lines whose order matters (numbered steps).
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

awk -v seed="$RANDOM$$" '
BEGIN {
  srand(seed)
  split("login|search|export|billing|upload|sync|reports|cache|api|mobile|search index|audit trail|dark mode", feat, "|")
  split("Fixed a crash in the|Added retry logic to the|Sped up the|Reworked the|Removed a deprecated option from the|Documented the|Reduced memory use of the", act, "|")
  n = 10 + int(rand() * 7)
  maj = 1; min = 0; pat = 0
  d = 20260101 - 30000
  for (i = 1; i <= n; i++) {
    r = rand()
    if (r < 0.15) { maj++; min = 0; pat = 0 } else if (r < 0.5) { min++; pat = 0 } else pat++
    m = 1 + int((i - 1) * 11 / n); day = 1 + int(rand() * 27)
    print "----"
    printf "v%d.%d.%d  (2025-%02d-%02d)\n", maj, min, pat, m, day
    k = 2 + int(rand() * 5)
    for (j = 1; j <= k; j++)
      printf "%d. %s %s (ticket #%d)\n", j, act[1 + int(rand() * 7)], feat[1 + int(rand() * 13)], 1000 + int(rand() * 8000)
  }
}' > CHANGES
cksum < CHANGES > .lm-state/changes.sum
