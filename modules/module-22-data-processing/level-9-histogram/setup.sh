#!/bin/bash
# JMeter results: fast requests, a slower group, and timeouts far above one
# second. One or two buckets between 500 and 999 ms are empty, values sit
# exactly on bucket boundaries, and the Latency column (time to first byte)
# is a tempting wrong choice next to elapsed.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

awk -v seed="$RANDOM$$" '
BEGIN {
  srand(seed)
  e1 = 5 + int(rand() * 5); e2 = (rand() < 0.5) ? e1 : 5 + int(rand() * 5)
  nl = split("GET /cart|POST /checkout|GET /product|POST /payment|GET /shipping-options", label, "|")
  print "timeStamp,elapsed,label,responseCode,responseMessage,threadName,success,bytes,Latency"
  n = 1100 + int(rand() * 700)
  t = 1762729200000 + int(rand() * 3600) * 1000
  for (i = 1; i <= n; i++) {
    do {
      r = rand()
      if (r < 0.03)      v = 100 * (1 + int(rand() * 10))            # exactly on a boundary
      else if (r < 0.55) v = 15 + int(rand() * 230)
      else if (r < 0.85) v = 200 + int(rand() * 350)
      else if (r < 0.93) v = 450 + int(rand() * 550)
      else               v = 1000 + int(rand() * 29000)
      b = int(v / 100)
    } while (b == e1 || b == e2)
    code = 200; msg = "OK"; ok = "true"
    if (v >= 1000 && rand() < 0.6) { code = "Non HTTP response code: java.net.SocketTimeoutException"; msg = "Read timed out"; ok = "false" }
    else if (rand() < 0.02) { code = 500; msg = "Internal Server Error"; ok = "false" }
    lat = int(v * (0.3 + rand() * 0.6))
    t += int(rand() * 900)
    printf "%d,%d,%s,%s,%s,Checkout users 1-%d,%s,%d,%d\n", t, v, label[int(rand() * nl) + 1], code, msg, 1 + int(rand() * 50), ok, 300 + int(rand() * 9000), lat
  }
}' > results.jtl

cksum < results.jtl > .lm-state/results.sum
