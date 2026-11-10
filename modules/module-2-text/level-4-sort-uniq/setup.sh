#!/bin/bash
# $1 = sandbox path
SANDBOX="$1"
cd "$SANDBOX" || exit 1

# 14 clients with different request counts, interleaved like real traffic
ips=(198.51.100.23 10.0.0.5 192.168.1.10 203.0.113.77 192.168.1.20 10.0.0.12 \
     172.16.4.2 192.168.1.30 203.0.113.9 10.0.0.99 198.51.100.4 172.16.4.18 \
     192.168.1.40 203.0.113.250)
counts=(143 121 97 88 76 64 55 47 39 31 22 14 9 3)
paths=(/api/products /api/cart /api/search?q=shoes /api/orders /health /api/products/42)

n=0
for r in $(seq 0 142); do
  for j in $(seq 0 13); do
    k=$(( (j + r) % 14 ))
    [ "$r" -lt "${counts[$k]}" ] || continue
    n=$(( n + 1 ))
    t=$(( 28800 + n * 13 ))
    printf '%s - - [15/Mar/2024:%02d:%02d:%02d +0000] "GET %s HTTP/1.1" 200 %d "-" "client/1.0"\n' \
      "${ips[$k]}" $(( t / 3600 )) $(( t / 60 % 60 )) $(( t % 60 )) \
      "${paths[$(( n % 6 ))]}" $(( 200 + n * 37 % 5000 ))
  done
done > access.log
