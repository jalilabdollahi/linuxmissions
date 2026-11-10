#!/bin/bash
# Pattern Mastery: ~200 log lines with IPv4 addresses in many positions
# (after "client=", with :port, in [brackets], two per line) mixed with
# lookalikes: versions (3.12.4), build ids (2024.04.08.1), decimals.
SANDBOX="$1"

awk 'BEGIN {
  split("10.0.0.7 10.0.0.12 10.0.3.250 172.16.4.20 172.16.4.21 192.168.1.10 192.168.1.200 192.168.10.5 203.0.113.9 203.0.113.77 198.51.100.23 8.8.8.8 100.64.0.1 127.0.0.1", ip, " ")
  split("alice bob carol dave erin frank", user, " ")
  for (i = 0; i < 200; i++) {
    ts = sprintf("2024-04-08T%02d:%02d:%02dZ", 6 + int(i / 20), (i * 7) % 60, (i * 13) % 60)
    a = ip[(i * 5) % 14 + 1]; b = ip[(i * 3 + 4) % 14 + 1]; u = user[i % 6 + 1]
    k = i % 9
    if (k == 0)      printf "%s INFO  client=%s user=%s action=login\n", ts, a, u
    else if (k == 1) printf "%s WARN  upstream %s:8443 slow (%d.%02ds)\n", ts, a, 1 + i % 3, i % 100
    else if (k == 2) printf "%s INFO  build 2024.04.08.%d deployed (app version 3.12.%d)\n", ts, i % 5 + 1, i % 9
    else if (k == 3) printf "%s ERROR [%s] connection reset by peer\n", ts, a
    else if (k == 4) printf "%s INFO  forwarded-for: %s, %s\n", ts, a, b
    else if (k == 5) printf "%s DEBUG cache hit ratio 0.%02d latency %d.%dms\n", ts, 50 + i % 50, i % 40, i % 10
    else if (k == 6) printf "%s INFO  user=%s downloaded report-%d.%d.pdf\n", ts, u, i % 12 + 1, i % 30
    else if (k == 7) printf "%s WARN  failed password for %s from %s port %d\n", ts, u, b, 40000 + i
    else             printf "%s INFO  healthcheck ok, uptime %d.%d days\n", ts, i % 20, i % 10
  }
}' > "$SANDBOX/app.log"
