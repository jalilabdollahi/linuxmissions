#!/bin/bash
# Two service logs over the same ~40 minutes: billing in epoch seconds, notify
# in epoch milliseconds (13 digits). Bursts put several lines of one service
# in the same second, not in alphabetical order, so only a stable sort keeps
# them right.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

awk -v seed="$RANDOM$$" '
BEGIN {
  srand(seed)
  t0 = 1794200000 + int(rand() * 160000)
  order = 88000 + int(rand() * 9000)
  t = t0; nb = 0; nn = 0
  for (k = 1; k <= 140; k++) {
    t += int(rand() * 18)
    order++
    amt = sprintf("%.2f", 5 + rand() * 300)
    if (rand() < 0.15) {
      B[++nb] = t " WARN card declined order=" order " code=" ((rand() < 0.5) ? "51" : "05")
      if (rand() < 0.6) B[++nb] = t " INFO charge accepted order=" order " amount=" amt " retry=1"
      else continue
    } else {
      B[++nb] = t " INFO charge accepted order=" order " amount=" amt
    }
    if (rand() < 0.5) B[++nb] = t " INFO charge captured order=" order
    if (rand() < 0.05) B[++nb] = t " INFO refund issued order=" (order - 1 - int(rand() * 20))
    # notify reacts within 0-2 s, in milliseconds
    ms = t * 1000 + int(rand() * 2000)
    if (rand() < 0.04) {
      N[++nn] = ms " WARN email bounced order=" order " smtp=550"
      N[++nn] = (ms + int(rand() * 30)) " INFO sms sent order=" order
    } else {
      N[++nn] = ms " INFO email queued order=" order " template=receipt"
      N[++nn] = (ms + int(rand() * 400)) " INFO email sent order=" order
    }
    if (rand() < 0.3) N[++nn] = (ms + 400 + int(rand() * 500)) " INFO webhook delivered order=" order " status=200"
  }
  # notify lines may interleave between orders: put them in time order
  for (i = 2; i <= nn; i++) { v = N[i]; split(v, a, " "); j = i - 1
    while (j > 0) { split(N[j], b, " "); if (b[1] + 0 <= a[1] + 0) break; N[j + 1] = N[j]; j-- }
    N[j + 1] = v }
  for (i = 1; i <= nb; i++) print B[i] > "billing.log"
  for (i = 1; i <= nn; i++) print N[i] > "notify.log"
}'

cat billing.log notify.log | cksum > .lm-state/logs.sum
