#!/bin/bash
# $1 = sandbox path
# Two mock DNS servers on loopback stand for the two nameservers in
# etc/resolv.conf: the old one (drops every query) and the live one. Both
# log every query they receive into logs/. bin/getent is a stub resolver
# that applies glibc's rules to etc/resolv.conf (search list, ndots,
# timeout, attempts, rotate) and sends real queries.
# Broken on purpose: the dead server is listed first, ndots:5 sends
# db.corp.example through the whole search list first, and the domain where
# the short service names live (random: svc/apps/k8s) is last in the list.
SANDBOX="$1"
NET="$SANDBOX/.net"
mkdir -p "$NET" "$SANDBOX/etc" "$SANDBOX/bin" "$SANDBOX/logs"
MOCKS="$(cd "$(dirname "$0")/../../../mocks/net" && pwd)"
cp "$MOCKS/dns_server.py" "$NET/"
cd "$SANDBOX" || exit 1

svc=$(printf 'svc\napps\nk8s\n' | shuf -n1)
dead="10.53.0.$(( RANDOM % 40 + 5 ))"
live="10.53.0.$(( RANDOM % 40 + 50 ))"
echo "$svc" > "$NET/svcdomain"

cat > "$NET/corp.zone" <<EOF
\$ORIGIN corp.example.
\$TTL 300
@          IN SOA ns1 hostmaster ( 2026111004 3600 600 86400 300 )
@             NS    ns1
ns1           A     $live
db            A     10.53.2.$(( RANDOM % 200 + 20 ))
wiki          A     10.53.3.$(( RANDOM % 200 + 20 ))
mail          A     10.53.3.25
api.$svc      A     10.53.1.$(( RANDOM % 200 + 20 ))
queue.$svc    A     10.53.1.$(( RANDOM % 200 + 20 ))
grafana.lab   A     10.53.4.$(( RANDOM % 200 + 20 ))
EOF
echo '*  drop' > "$NET/dead.rules"

python3 "$NET/dns_server.py" --zone "$NET/corp.zone" --log "logs/dns-$live.log" \
  --port-file "$NET/live.port" --idle-timeout 0 --daemon \
  || { echo "could not start the DNS server" >&2; exit 1; }
python3 "$NET/dns_server.py" --zone "$NET/corp.zone" --rules "$NET/dead.rules" --log "logs/dns-$dead.log" \
  --port-file "$NET/dead.port" --idle-timeout 0 --daemon \
  || { echo "could not start the second DNS server" >&2; exit 1; }
printf '%s %s\n%s %s\n' "$dead" "$(cat "$NET/dead.port")" "$live" "$(cat "$NET/live.port")" > "$NET/nameservers"

others=$(printf 'corp.example\nlab.corp.example\n' | shuf)
cat > etc/resolv.conf <<EOF
# resolver settings for app-12 (from the 2023 provisioning template)
domain corp.example
search $(echo $others) $svc.corp.example
nameserver $dead
nameserver $live
options ndots:5 timeout:3 attempts:2
EOF

cat > bin/getent <<'PY'
#!/usr/bin/env python3
"""getent hosts NAME - a stub resolver following glibc's rules for this lab's
etc/resolv.conf. Nameserver addresses are mapped to the lab's DNS servers
on 127.0.0.1 (.net/nameservers); any other address never answers."""
import os, random, socket, struct, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ports = dict(l.split() for l in open(os.path.join(ROOT, ".net/nameservers")) if l.strip())

def conf():
    ns, search, opts = [], [], {"ndots": 1, "timeout": 5, "attempts": 2, "rotate": False}
    for line in open(os.path.join(ROOT, "etc/resolv.conf")):
        w = line.split()
        if not w or w[0][0] in "#;":
            continue
        if w[0] == "nameserver" and len(w) > 1 and len(ns) < 3:
            ns.append(w[1])
        elif w[0] in ("search", "domain"):
            search = w[1:] if w[0] == "search" else w[1:2]      # the last one wins
        elif w[0] == "options":
            for o in w[1:]:
                k, _, v = o.partition(":")
                if k in ("ndots", "timeout", "attempts") and v.isdigit():
                    opts[k] = min(int(v), {"ndots": 15, "timeout": 30, "attempts": 5}[k])
                elif k == "rotate":
                    opts["rotate"] = True
    return ns or ["127.0.0.1"], search, opts

def query(server, name, timeout):
    """'ok' + addresses, 'nxdomain', 'servfail' or 'timeout'."""
    port = ports.get(server)
    qid = random.randrange(65536)
    pkt = struct.pack(">HHHHHH", qid, 0x0100, 1, 0, 0, 0)
    pkt += b"".join(bytes([len(p)]) + p.encode() for p in name.rstrip(".").split(".")) + b"\0\0\1\0\1"
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.settimeout(timeout)
    try:
        if port is None:
            raise socket.timeout
        s.sendto(pkt, ("127.0.0.1", int(port)))
        data = s.recv(4096)
    except (socket.timeout, OSError):
        return "timeout", []
    rcode = data[3] & 15
    if rcode == 3:
        return "nxdomain", []
    if rcode != 0:
        return "servfail", []
    i = 12
    while data[i]:
        i += data[i] + 1
    i += 5
    addrs = []
    for _ in range(struct.unpack(">H", data[6:8])[0]):
        while data[i] and data[i] < 0xC0:
            i += data[i] + 1
        i += 2 if data[i] >= 0xC0 else 1
        rtype, _, _, rdlen = struct.unpack(">HHIH", data[i:i + 10])
        i += 10
        if rtype == 1:
            addrs.append(socket.inet_ntoa(data[i:i + rdlen]))
        i += rdlen
    return ("ok", addrs) if addrs else ("nxdomain", [])

def resolve(name):
    ns, search, o = conf()
    if name.endswith("."):
        cands = [name]
    else:
        searched = [f"{name}.{d.rstrip('.')}." for d in search]
        cands = [name + "."] + searched if name.count(".") >= o["ndots"] else searched + [name + "."]
    start = random.randrange(len(ns)) if o["rotate"] else 0
    order = ns[start:] + ns[:start]
    for cand in cands:
        answered = False
        for _ in range(o["attempts"]):
            for server in order:
                status, addrs = query(server, cand, o["timeout"])
                if status == "ok":
                    return cand.rstrip("."), addrs
                if status == "nxdomain":
                    answered = True
                    break
            if answered:
                break
    return None, []

args = sys.argv[1:]
if len(args) < 2 or args[0] != "hosts":
    print("usage: getent hosts NAME...   (this lab's getent resolves through etc/resolv.conf)", file=sys.stderr)
    sys.exit(1)
rc = 0
for n in args[1:]:
    fqdn, addrs = resolve(n)
    if addrs:
        print(f"{addrs[0]:<15} {fqdn}")
    else:
        rc = 2
sys.exit(rc)
PY
chmod +x bin/getent
cp bin/getent "$NET/getent.orig"

cat > TICKET.txt <<EOF
OPS-4120  Short names are slow on app-12

Our services call each other by short names (api, queue). On app-12 every
such lookup takes several seconds; full names are slow too. The network team
says both DNS servers in etc/resolv.conf were checked: $dead is the old
server that was switched off last month, $live is the current one. The
lab's DNS servers log every query they receive (logs/).

Fix etc/resolv.conf so that:
- \`getent hosts api\` is answered by the very first query the resolver sends,
- full names such as db.corp.example are asked as they are on the first
  query (not glued to the search domains first),
- the switched-off server is no longer used,
- short names in any of our current search domains still resolve.
EOF
