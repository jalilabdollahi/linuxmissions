#!/bin/bash
# alert.txt: three long single-line paragraphs; one contains a random URL of
# 80-110 characters and one contains a double space.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

awk -v seed="$RANDOM$$" '
function words(n,   s, i) {
  s = ""
  for (i = 0; i < n; i++) s = s (i ? " " : "") w[1 + int(rand() * nw)]
  return s
}
BEGIN {
  srand(seed)
  nw = split("database replica lagging behind primary checkout service latency above threshold restart pending queue depth growing customers affected payment gateway timeouts rollback prepared on-call engineer paged runbook step verified disk usage normal traffic shifted region failover completed monitoring continues", w, " ")
  tok = ""; for (i = 0; i < 40; i++) tok = tok substr("abcdefghijklmnopqrstuvwxyz0123456789", 1 + int(rand() * 36), 1)
  url = "https://status.example.org/incidents/2026/" tok "/details?view=timeline"
  printf "ALERT %d CRITICAL: %s. Impact: %s.\n", 1000 + int(rand() * 8000), words(28), words(22)
  printf "Details at %s  then follow %s, owner: team-%s.\n", url, words(30), words(1)
  printf "UPDATE: %s. Next update in %d minutes unless %s.\n", words(34), 10 + int(rand() * 4) * 5, words(12)
}' > alert.txt
cp alert.txt .lm-state/alert.orig
