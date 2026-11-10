#!/bin/bash
# $1 = sandbox path
# corp.example is served by ns1 (primary) and two secondaries, each a mock
# authoritative DNS server on 127.0.0.1 with its own port. One secondary
# (random: ns2 or ns3) stopped transferring a week ago: its SOA serial is
# old, it lacks the new pay-v2 record and still has checkout's old address.
# Everything else is identical, so spot checks with www/mail look fine.
# etc/resolv.conf lists all three with "options rotate"; bin/smoke-dns is
# the app team's check (20 lookups round-robin through resolv.conf, then a
# "connect" that only succeeds for addresses that are really in service).
SANDBOX="$1"
NET="$SANDBOX/.net"
mkdir -p "$NET" "$SANDBOX/etc" "$SANDBOX/bin"
MOCKS="$(cd "$(dirname "$0")/../../../mocks/net" && pwd)"
cp "$MOCKS/dns_server.py" "$NET/"
cd "$SANDBOX" || exit 1

stale=$(printf 'ns2\nns3\n' | shuf -n1)
day=$(( RANDOM % 5 + 10 ))
good_serial="202611${day}0$(( RANDOM % 8 + 2 ))"
stale_serial="202611$(printf '%02d' $(( day - 7 )))0$(( RANDOM % 8 + 1 ))"
o() { echo $(( RANDOM % 200 + 20 )); }
www=$(o) mail=$(o) api=$(o) pay=$(o) git=$(o) static=$(o)
checkout_new="10.60.2.$(o)" checkout_old="10.60.9.$(o)" payv2="10.60.2.$(o)"

zone() {  # serial checkout_ip with_payv2
  cat <<EOF
\$ORIGIN corp.example.
\$TTL 300
@          IN SOA ns1 hostmaster ( $1 3600 600 1209600 300 )
@             NS    ns1
@             NS    ns2
@             NS    ns3
ns1           A     10.53.1.11
ns2           A     10.53.1.12
ns3           A     10.53.1.13
@             MX    10 mail
www           A     10.60.1.$www
mail          A     10.60.1.$mail
api           A     10.60.2.$api
payments      A     10.60.2.$pay
checkout      A     $2
git           A     10.60.3.$git
static        CNAME www
EOF
  [ "$3" = yes ] && echo "pay-v2        A     $payv2"
  [ "$3" = yes ] && echo "status        A     10.60.1.$static"
  return 0
}
zone "$good_serial" "$checkout_new" yes > "$NET/primary.zone"
zone "$stale_serial" "$checkout_old" no > "$NET/stale.zone"

for ns in ns1 ns2 ns3; do
  z=primary.zone
  [ "$ns" = "$stale" ] && z=stale.zone
  python3 "$NET/dns_server.py" --mode auth --zone "$NET/$z" --log "$NET/$ns.log" \
    --port-file "$NET/$ns.port" --idle-timeout 0 --daemon \
    || { echo "could not start $ns" >&2; exit 1; }
done
p1=$(cat "$NET/ns1.port") p2=$(cat "$NET/ns2.port") p3=$(cat "$NET/ns3.port")
printf '10.53.1.11 %s\n10.53.1.12 %s\n10.53.1.13 %s\n' "$p1" "$p2" "$p3" > "$NET/nameservers"
printf '%s\n' "$checkout_new" "$payv2" "10.60.1.$www" "10.60.2.$api" "10.60.2.$pay" > "$NET/in-service"

cat > servers.txt <<EOF
# corp.example name servers
# In this lab each one listens on 127.0.0.1 with its own port:
#   dig @127.0.0.1 -p PORT NAME [TYPE]
# name  address      role        lab port
ns1     10.53.1.11   primary     $p1
ns2     10.53.1.12   secondary   $p2
ns3     10.53.1.13   secondary   $p3
EOF

cat > etc/resolv.conf <<'EOF'
# app-21: spread the load over all corp.example name servers (INFRA-77)
search corp.example
nameserver 10.53.1.11
nameserver 10.53.1.12
nameserver 10.53.1.13
options rotate timeout:2 attempts:2
EOF

cat > bin/smoke-dns <<'PY'
#!/usr/bin/env python3
"""smoke-dns: the checkout team's DNS smoke test. 20 lookups of the names
checkout needs, through etc/resolv.conf (nameservers in order, or round-robin
with "options rotate"), each followed by a connection attempt."""
import os, random, socket, struct, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ports = dict(l.split() for l in open(os.path.join(ROOT, ".net/nameservers")) if l.strip())
up = set(open(os.path.join(ROOT, ".net/in-service")).read().split())
NAMES = ["payments.corp.example", "checkout.corp.example", "pay-v2.corp.example", "api.corp.example", "www.corp.example"]

ns, rotate, timeout = [], False, 5
for line in open(os.path.join(ROOT, "etc/resolv.conf")):
    w = line.split()
    if not w or w[0][0] in "#;":
        continue
    if w[0] == "nameserver" and len(w) > 1 and len(ns) < 3:
        ns.append(w[1])
    if w[0] == "options":
        for opt in w[1:]:
            rotate |= opt == "rotate"
            if opt.startswith("timeout:") and opt[8:].isdigit():
                timeout = min(int(opt[8:]), 30)
if not ns:
    ns = ["127.0.0.1"]

def ask(server, name):
    port = ports.get(server)
    if port is None:
        return "timeout", None
    pkt = struct.pack(">HHHHHH", random.randrange(65536), 0x0100, 1, 0, 0, 0)
    pkt += b"".join(bytes([len(p)]) + p.encode() for p in name.split(".")) + b"\0\0\1\0\1"
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.settimeout(timeout)
    try:
        s.sendto(pkt, ("127.0.0.1", int(port)))
        data = s.recv(4096)
    except OSError:
        return "timeout", None
    if data[3] & 15 == 3:
        return "nxdomain", None
    if data[3] & 15:
        return "servfail", None
    i = 12
    while data[i]:
        i += data[i] + 1
    i += 5
    for _ in range(struct.unpack(">H", data[6:8])[0]):
        while data[i] and data[i] < 0xC0:
            i += data[i] + 1
        i += 2 if data[i] >= 0xC0 else 1
        rtype, _, _, rdlen = struct.unpack(">HHIH", data[i:i + 10])
        i += 10
        if rtype == 1:
            return "ok", socket.inet_ntoa(data[i:i + rdlen])
        i += rdlen
    return "nxdomain", None

ok = 0
for n in range(20):
    name = NAMES[n % len(NAMES)]
    start = n % len(ns) if rotate else 0
    status, addr = "timeout", None
    for server in ns[start:] + ns[:start]:
        status, addr = ask(server, name)
        if status != "timeout" and status != "servfail":
            break
    if status == "ok" and addr in up:
        ok += 1
        print(f"ok    {name:<24} {addr}")
    elif status == "ok":
        print(f"FAIL  {name:<24} {addr}: connect: Connection timed out")
    elif status == "nxdomain":
        print(f"FAIL  {name:<24} Name or service not known")
    else:
        print(f"FAIL  {name:<24} Temporary failure in name resolution")
print(f"{ok}/20 lookups ok")
sys.exit(0 if ok == 20 else 1)
PY
chmod +x bin/smoke-dns
cp bin/smoke-dns "$NET/smoke-dns.orig"

cat > TICKET.txt <<'EOF'
INC-3381  checkout: "payment backend unreachable" about one time in three

Since the payments migration last week, checkout on app-21 fails roughly
every third request: sometimes "Name or service not known" for pay-v2,
sometimes a timeout talking to checkout's own API. A retry usually works.
The checkout team's smoke test (smoke-dns, on your PATH) shows it.

app-21 resolves through etc/resolv.conf; the name servers are listed in
servers.txt. The DNS team swears "DNS is fine, we checked www on all of
them".

1. Find the name server that serves out-of-date data, and prove it with
   the zone's serial numbers. Write triage.env:
     STALE=<ns1, ns2 or ns3>
     STALE_SERIAL=<the corp.example serial that server has>
     GOOD_SERIAL=<the primary's serial>
2. Fix etc/resolv.conf so app-21 no longer gets answers from the stale
   server, until the DNS team repairs it. smoke-dns must pass 20/20.
EOF
