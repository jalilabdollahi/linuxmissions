#!/bin/bash
# Local DNS server for the names a monitoring script watches. Per setup, one
# of two partner zones is broken (SERVFAIL for everything in it), one name is
# silently dropped (client times out), some names don't exist (NXDOMAIN) and
# the rest resolve. The expected status per name goes to .net/expected.tsv.
SANDBOX="$1"
NET="$SANDBOX/.net"; mkdir -p "$NET"
MOCKS="$(cd "$(dirname "$0")/../../../mocks/net" && pwd)"
cp "$MOCKS/dns_server.py" "$NET/"

python3 - "$SANDBOX" <<'PY'
import random, sys
sb = sys.argv[1]
net = f"{sb}/.net"
corp = ["www", "api", "vpn", "git", "wiki", "grafana", "sso", "status", "ci", "vault"]
other = {"partners.example": ["edi", "sftp", "portal", "invoices"],
         "legacy.example": ["crm", "intranet", "hr", "timesheets"]}
broken = random.choice(sorted(other))
fine = [z for z in other if z != broken][0]

random.shuffle(corp)
ok = [f"{corp[0]}.corp.example", f"{corp[1]}.corp.example",
      f"{random.choice(other[fine])}.{fine}"]
timeout = f"{corp[2]}.corp.example"
nx = [f"{corp[3]}.corp.example", f"{random.choice(['jira', 'nagios', 'old-mail', 'svn'])}.corp.example"]
sf = [f"{n}.{broken}" for n in random.sample(other[broken], 2)]

status = {**{n: "OK" for n in ok}, timeout: "TIMEOUT", **{n: "NXDOMAIN" for n in nx},
          **{n: "SERVFAIL" for n in sf}}
names = list(status)
random.shuffle(names)

def ip():
    return f"10.{random.randint(20, 40)}.{random.randint(0, 255)}.{random.randint(2, 250)}"

zone = ["$ORIGIN corp.example.", "$TTL 300",
        "@ IN SOA ns1 hostmaster ( 2026111001 3600 600 86400 300 )", "@ NS ns1", "ns1 A 127.0.0.1"]
for n in corp[:3] + corp[4:]:              # corp[3] is gone: NXDOMAIN
    zone.append(f"{n} A {ip()}")
for z, hosts in other.items():
    zone += ["", f"$ORIGIN {z}.", "@ IN SOA ns1.corp.example. hostmaster.corp.example. ( 2026103101 3600 600 86400 300 )"]
    zone += [f"{h} A {ip()}" for h in hosts]
open(f"{net}/zone.db", "w").write("\n".join(zone) + "\n")
open(f"{net}/rules", "w").write(f".{broken}. servfail\n{timeout} drop\n")
open(f"{sb}/names.txt", "w").write("\n".join(names) + "\n")
open(f"{net}/expected.tsv", "w").write("".join(f"{n}\t{status[n]}\n" for n in names))
PY

python3 "$NET/dns_server.py" --zone "$NET/zone.db" --rules "$NET/rules" --log "$NET/query.log" \
    --port-file "$SANDBOX/dns.port" --daemon \
  || { echo "could not start the DNS server" >&2; exit 1; }

cat > "$SANDBOX/TICKET.txt" <<'EOF'
TICKET-6402  check_dns needs a status per name
----------------------------------------------
Our monitoring script only knows "lookup failed", and on-call can't
tell a typo from a dead DNS server. For each name in names.txt, ask the
test resolver (127.0.0.1, port in dns.port) and record what really
happened, as results.tsv:

    NAME<TAB>STATUS

STATUS is one of:
  OK        the name resolves to an address
  NXDOMAIN  the server says the name does not exist
  SERVFAIL  the server answered, but with a server failure
  TIMEOUT   the server never answered
EOF
