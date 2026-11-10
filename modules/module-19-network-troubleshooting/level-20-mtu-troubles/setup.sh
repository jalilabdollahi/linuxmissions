#!/bin/bash
# $1 = sandbox path
# bin/vpnping HOST SIZE behaves like `ping -c 1 -W 2 -M do -s SIZE HOST`
# through the WireGuard tunnel: packets larger than the path MTU (random
# 1300-1452 per setup) vanish silently (an ICMP black hole), larger than the
# local wg0 MTU (1500) fail with "message too long". Each probe takes about
# a second (two when lost), so trying every size is slow; a binary search
# needs about ten probes. Every probe is logged for the validator.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p bin .vpn netplan

pmtu=$(( RANDOM % 153 + 1300 ))
printf '1500\n1500\n%s\n1500\n' "$pmtu" > .vpn/hops   # MTU of each hop on the path
: > .vpn/probes.log

cat > bin/vpnping <<'PY'
#!/usr/bin/env python3
"""vpnping HOST SIZE - one don't-fragment ICMP echo through wg0 (ping -c1 -W2 -M do -s SIZE)."""
import os, random, sys, time

here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FAR = "10.99.0.1"
LOCAL_MTU = 1500
args = sys.argv[1:]
if len(args) != 2 or not args[1].isdigit():
    print("usage: vpnping HOST SIZE   (like: ping -c 1 -W 2 -M do -s SIZE HOST)", file=sys.stderr)
    sys.exit(2)
host, size = args[0], int(args[1])
if host not in (FAR, "vpn-fra"):
    print(f"ping: connect: Network is unreachable ({host} is not on the tunnel; the far end is {FAR})", file=sys.stderr)
    sys.exit(2)
if size > 65507:
    print(f"ping: invalid argument: '{size}': out of range: 0 <= value <= 65507", file=sys.stderr)
    sys.exit(2)
path_mtu = min(int(x) for x in open(os.path.join(here, ".vpn/hops")) if x.strip())
total = size + 28
print(f"PING {FAR} ({FAR}) {size}({total}) bytes of data.")
sys.stdout.flush()
if total > LOCAL_MTU:
    result = "local"
    print(f"ping: local error: message too long, mtu={LOCAL_MTU}")
    time.sleep(1.0)
elif total > path_mtu:
    result = "lost"
    time.sleep(2.0)
else:
    result = "ok"
    rtt = random.uniform(21.0, 26.0)
    time.sleep(0.9)
    print(f"{size + 8} bytes from {FAR}: icmp_seq=1 ttl=63 time={rtt:.1f} ms")
with open(os.path.join(here, ".vpn/probes.log"), "a") as log:
    log.write(f"{time.time():.3f} {size} {result}\n")
print(f"\n--- {FAR} ping statistics ---")
if result == "ok":
    print("1 packets transmitted, 1 received, 0% packet loss, time 0ms")
    print(f"rtt min/avg/max/mdev = {rtt:.3f}/{rtt:.3f}/{rtt:.3f}/0.000 ms")
    sys.exit(0)
errors = ", +1 errors" if result == "local" else ""
print(f"1 packets transmitted, 0 received{errors}, 100% packet loss, time 0ms")
sys.exit(1)
PY
chmod +x bin/vpnping

cat > netplan/60-vpn.yaml <<'EOF'
# WireGuard tunnel to the Frankfurt office (NET-3001)
network:
  version: 2
  tunnels:
    wg0:
      mode: wireguard
      addresses: [10.99.0.6/24]
      mtu: 1500
      port: 51820
      key: /etc/wireguard/wg0.key
      peers:
        - keys:
            public: 3oVZb5hmuh0LzxvJ1G0f0yR2ZsS6m0tO/Nk3tLp6x2Q=
          allowed-ips: [10.99.0.0/24, 10.60.0.0/16]
          endpoint: 198.51.100.40:51820
          keepalive: 25
EOF
cp netplan/60-vpn.yaml .vpn/orig.yaml

cat > TICKET.txt <<'EOF'
NET-3019  VPN to Frankfurt: small things work, uploads hang

Since the tunnel went live, ssh and the web UI over wg0 work fine, but
uploads and git pushes hang forever. Smells like an MTU problem: somewhere on
the path the packets get too big, and whatever is supposed to tell us
"fragmentation needed" never arrives.

This lab machine can't reach the real tunnel, so the network team left
`vpnping HOST SIZE` (in bin/, it's on your PATH) that replays it. It sends
ONE don't-fragment echo with SIZE bytes of payload through the tunnel to the
far end, 10.99.0.1, exactly like `ping -c 1 -W 2 -M do -s SIZE HOST`.

1. Find the path MTU through the tunnel: the largest IP packet (headers
   included) that gets through. Write just that number to pmtu.txt.
2. Set wg0's mtu in netplan/60-vpn.yaml to that value (change nothing else).
EOF
