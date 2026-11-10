#!/bin/bash
# One probe per minute for a whole day. Short outages in some hours, one hour
# of flapping (many 1-3 minute outages, which add up to a lot of DOWN minutes),
# and one clearly longest outage whose error changes midway (timeout, then
# connection refused, then 503), so grouping by status+error splits it.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

awk -v seed="$RANDOM$$" '
BEGIN {
  srand(seed)
  ne = split("timeout conn_refused http_503 http_502 tls_handshake", err, " ")
  for (m = 0; m < 1440; m++) down[m] = 0
  longh = 6 + int(rand() * 14)                     # hour of the longest outage
  do flaph = int(rand() * 24); while (flaph == longh)
  for (h = 0; h < 24; h++) {
    base = h * 60
    if (h == flaph) {                               # flapping: short bursts
      m = base + 3
      while (m < base + 57) { len = 1 + int(rand() * 3); for (k = 0; k < len; k++) down[m + k] = 1; m += len + 1 + int(rand() * 3) }
    } else if (h == longh) {
      len = 28 + int(rand() * 20); s = base + 3 + int(rand() * (54 - len))
      for (k = 0; k < len; k++) down[s + k] = (k < len / 3) ? 2 : (k < 2 * len / 3) ? 3 : 4
    } else if (rand() < 0.45) {
      len = 1 + int(rand() * 20); s = base + 3 + int(rand() * (54 - len))
      for (k = 0; k < len; k++) down[s + k] = 1
    }
  }
  for (m = 0; m < 1440; m++) {
    ts = sprintf("2026-11-09T%02d:%02d:00Z", int(m / 60), m % 60)
    if (down[m] == 0) printf "%s UP %dms\n", ts, 40 + int(rand() * 160 + rand() * rand() * 900)
    else if (down[m] == 1) printf "%s DOWN %s\n", ts, err[int(rand() * ne) + 1]
    else printf "%s DOWN %s\n", ts, err[down[m] - 1]
  }
}' > probe.log

cksum < probe.log > .lm-state/probe.sum
