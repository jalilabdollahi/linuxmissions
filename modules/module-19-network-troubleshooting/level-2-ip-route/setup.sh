#!/bin/bash
# `ip route` from the jump host jh-02 and the destinations the change request
# asks about. Addresses and gateways change per setup; the validator does the
# longest-prefix match itself.
SANDBOX="$1"

a=$((10 + RANDOM % 200))           # jump host LAN 10.0.a.0/24 on ens3
me=$((20 + RANDOM % 200))
gdef=1
g16=$((240 + RANDOM % 10))         # gateway for 10.50.0.0/16
g32=$((230 + RANDOM % 9))          # gateway for the /32 host route
g5=$((220 + RANDOM % 9))           # gateway for 10.5.0.0/16
hx=$((1 + RANDOM % 120)); hy=$((2 + RANDOM % 240))   # 10.50.hx.hy/32
z=$((130 + RANDOM % 120))          # 10.50.z.0/24 directly on ens4
wgnet=$((RANDOM % 16))             # inside 10.99.0.0/20
wgout=$((16 + RANDOM % 200))       # outside it
p12=$((16 + RANDOM % 16))          # inside 172.16.0.0/12

cat > "$SANDBOX/routes.txt" <<EOF2
default via 10.0.$a.$gdef dev ens3 proto dhcp src 10.0.$a.$me metric 100 
10.0.$a.0/24 dev ens3 proto kernel scope link src 10.0.$a.$me metric 100 
10.0.$a.$gdef dev ens3 proto dhcp scope link src 10.0.$a.$me metric 100 
10.5.0.0/16 via 10.0.$a.$g5 dev ens3 proto static 
10.50.0.0/16 via 10.0.$a.$g16 dev ens3 proto static 
10.50.$hx.$hy via 10.0.$a.$g32 dev ens3 proto static 
10.50.$z.0/24 dev ens4 proto kernel scope link src 10.50.$z.$me 
10.99.0.0/20 dev wg0 proto kernel scope link src 10.99.0.$((2 + RANDOM % 9)) 
172.16.0.0/12 via 10.99.0.1 dev wg0 proto static onlink 
EOF2

# The destinations, in random order.
{
  echo "10.50.$hx.$hy"
  echo "10.50.$hx.$((hy + 1 + RANDOM % 5))"
  echo "10.50.$z.$((2 + RANDOM % 250))"
  echo "10.5.$((RANDOM % 256)).$((1 + RANDOM % 254))"
  echo "10.99.$wgnet.$((1 + RANDOM % 254))"
  echo "10.99.$wgout.$((1 + RANDOM % 254))"
  echo "172.$p12.$((RANDOM % 256)).$((1 + RANDOM % 254))"
  echo "172.$((32 + RANDOM % 10)).$((RANDOM % 256)).$((1 + RANDOM % 254))"
  echo "10.0.$a.$((2 + RANDOM % 15))"
} | awk 'BEGIN { srand() } { print rand() "\t" $0 }' | sort -n | cut -f2- > "$SANDBOX/destinations.txt"

cat > "$SANDBOX/TICKET.txt" <<'EOF2'
CHG-2291  Firewall change for the jump host jh-02
------------------------------------------------
Before we open the new flows we need to know which way jh-02 sends
traffic to each address in destinations.txt: through which next-hop
gateway and out of which interface. routes.txt is `ip route` from jh-02.

Please fill in answers.tsv, one line per destination, in the same order:
    DESTINATION  GATEWAY  INTERFACE
GATEWAY is the next-hop address, or the word direct when the destination
is on a directly connected network (no gateway).
EOF2
