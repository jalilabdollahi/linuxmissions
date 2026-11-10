#!/bin/bash
# Builds connections.txt: `ss -tan` on web-03 (10.20.4.17) during a slowdown.
# The data is generated deterministically (no $RANDOM), so the answer is fixed:
#   203.0.113.77 has 37 ESTABLISHED connections to local port 443.
# Traps: 198.51.100.23 has 30 ESTAB + 25 TIME-WAIT on 443 (55 if state is
# ignored), 10.20.4.30 is the database with 48 ESTAB connections that web-03
# opened itself (local port is random, peer port 5432), and an IPv6 client.
SANDBOX="$1"
TMP="$SANDBOX/.conn.tmp"
: > "$TMP"

row() {  # row STATE LOCAL PEER
  printf '%-10s %-6s %-6s %22s %26s\n' "$1" 0 0 "$2" "$3" >> "$TMP"
}

sport=32768
nextport() { sport=$(( (sport * 7 + 13) % 28000 + 32768 )); }

# Background clients: 60 addresses with 1-5 connections each.
for i in $(seq 1 60); do
  ip="100.64.$(( i % 7 )).$(( (i * 37) % 200 + 20 ))"
  for _ in $(seq 1 $(( i % 5 + 1 ))); do
    nextport; row ESTAB 10.20.4.17:443 "$ip:$sport"
  done
  if [ $(( i % 4 )) = 0 ]; then nextport; row TIME-WAIT 10.20.4.17:443 "$ip:$sport"; fi
done

# The top talker.
for _ in $(seq 1 37); do nextport; row ESTAB 10.20.4.17:443 "203.0.113.77:$sport"; done
# Many connections, but a lot of them are already closed.
for _ in $(seq 1 30); do nextport; row ESTAB 10.20.4.17:443 "198.51.100.23:$sport"; done
for _ in $(seq 1 25); do nextport; row TIME-WAIT 10.20.4.17:443 "198.51.100.23:$sport"; done
# Outgoing connection pool to the database.
for _ in $(seq 1 48); do nextport; row ESTAB "10.20.4.17:$sport" 10.20.4.30:5432; done
# IPv6 client.
for _ in $(seq 1 33); do nextport; row ESTAB "[2001:db8:4::17]:443" "[2001:db8:77::5]:$sport"; done
# Admins on SSH, monitoring on node_exporter, some half-open noise.
for ip in 10.20.4.101 10.20.4.102; do nextport; row ESTAB 10.20.4.17:22 "$ip:$sport"; done
for _ in $(seq 1 6); do nextport; row ESTAB 10.20.4.17:9100 "10.20.4.250:$sport"; done
for _ in $(seq 1 4); do nextport; row CLOSE-WAIT 10.20.4.17:443 "203.0.113.77:$sport"; done
for _ in $(seq 1 5); do nextport; row SYN-RECV 10.20.4.17:443 "192.0.2.66:$sport"; done

{
  printf '%-10s %-6s %-6s %22s %26s %s\n' State Recv-Q Send-Q "Local Address:Port" "Peer Address:Port" Process
  # Shuffle with a fixed key so every machine gets the same order.
  awk '{ printf "%07d %s\n", (NR * 7919) % 10007, $0 }' "$TMP" | sort -n | cut -d' ' -f2-
} > "$SANDBOX/connections.txt"
rm -f "$TMP"
