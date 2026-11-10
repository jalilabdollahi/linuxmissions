#!/bin/bash
# Weekly Cost Mail: the cloud cost export per team. A comment line, a header,
# team names padded with spaces, some longer than 20 characters (one exactly
# 20, one 21), costs padded with spaces, in exponent notation (1e3, 2.5E3)
# or with one decimal, and a credit (negative). Random per setup.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

awk -v seed="$RANDOM$$" '
BEGIN {
  srand(seed)
  n = split("Platform|Data Science|Mobile|Web Frontend|Customer Success Operations|Security Engineering|Payments|Search Relevance Team|Identity|Developer Experience and Tooling|Growth|Billing|Machine Learning Infrastructure|QA|Site Reliability", team, "|")
  for (i = n; i > 1; i--) { j = int(rand() * i) + 1; t = team[i]; team[i] = team[j]; team[j] = t }
  printf "# cloud cost export - week 45 - generated 2026-11-09T06:00:12Z\n"
  print "team,cost_usd"
  credit = int(rand() * n) + 1; e1 = (credit % n) + 1; e2 = (e1 % n) + 1; e3 = (e2 % n) + 1
  for (i = 1; i <= n; i++) {
    c = sprintf("%.2f", 80 + rand() * 24000)
    if (i == credit) c = sprintf("-%d.%02d", 50 + int(rand() * 400), int(rand() * 100))
    else if (i == e1) c = "1e3"
    else if (i == e2) c = (1 + int(rand() * 9)) ".5E3"
    else if (i == e3) c = sprintf("%.1f", 500 + rand() * 9000)
    nm = team[i]
    r = rand()
    if (r < 0.15) nm = "  " nm
    else if (r < 0.3) nm = nm " "
    r = rand()
    if (r < 0.3) c = "  " c
    else if (r < 0.45) c = c "   "
    print nm "," c
  }
  print ""
}' > costs.csv

cksum < costs.csv > .lm-state/costs.sum
