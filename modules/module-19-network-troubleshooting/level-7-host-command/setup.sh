#!/bin/bash
# DNS for the mail relay's sender check: PTR records for six sending IPs and
# the forward records of the names they point to. Which IP gets which kind of
# record (good, multi-A, CNAME, mismatch, no PTR, PTR without trailing dot)
# changes per setup; the failing set goes to .net/expected.
SANDBOX="$1"
NET="$SANDBOX/.net"; mkdir -p "$NET"
MOCKS="$(cd "$(dirname "$0")/../../../mocks/net" && pwd)"
cp "$MOCKS/dns_server.py" "$NET/"

python3 - "$SANDBOX" <<'PY'
import random, sys
sb = sys.argv[1]
net = f"{sb}/.net"
r = random.randint

nets = ["198.51.100", "203.0.113", "192.0.2"]
used = set()
def new_ip(lo=2, hi=250, pfx=None):
    while True:
        ip = f"{pfx or random.choice(nets)}.{r(lo, hi)}"
        if ip not in used:
            used.add(ip)
            return ip
def rev(ip):
    return ".".join(reversed(ip.split("."))) + ".in-addr.arpa."

doms = random.sample(["mailgun-eu.example", "acme-shop.example", "newsletter-hub.example",
                      "billing-cloud.example", "partner-crm.example", "ticketing.example",
                      "hr-portal.example", "status-mailer.example"], 6)
cases = ["good", "multi", "cname", "mismatch", "noptr", "nodot"]
random.shuffle(cases)

fwd, ptr, rev_blocks, ips, fail = [], [], [], [], []
for case, dom in zip(cases, doms):
    if case == "mismatch":
        while True:                            # forward A = the IP with one more digit
            ip = new_ip(2, 24)
            other = ip + str(r(0, 9))
            if other not in used:
                break
        used.add(other)
        name = f"smtp{r(1, 9)}.{dom}"
        ptr.append(f"{rev(ip)} PTR {name}.")
        fwd.append(f"{name}. A {other}")
        fail.append(ip)
    elif case == "good":
        ip = new_ip()
        name = f"mail.{dom}"
        ptr.append(f"{rev(ip)} PTR {name}.")
        fwd.append(f"{name}. A {ip}")
    elif case == "multi":
        ip = new_ip()
        name = f"out.{dom}"
        ptr.append(f"{rev(ip)} PTR {name}.")
        other = new_ip()
        pair = [ip, other]; random.shuffle(pair)
        fwd += [f"{name}. A {pair[0]}", f"{name}. A {pair[1]}"]
    elif case == "cname":
        ip = new_ip()
        name = f"bounce.{dom}"
        ptr.append(f"{rev(ip)} PTR {name}.")
        target = f"relay-{r(1, 4)}.{dom}."
        fwd += [f"{name}. CNAME {target}", f"{target} A {ip}"]
    elif case == "noptr":
        ip = new_ip()
        fwd.append(f"mta.{dom}. A {ip}")           # forward exists, reverse doesn't
        fail.append(ip)
    elif case == "nodot":
        ip = new_ip()
        name = f"mx.{dom}"
        o = ip.split(".")
        rev_blocks.append(f"$ORIGIN {o[2]}.{o[1]}.{o[0]}.in-addr.arpa.\n{o[3]} PTR {name}   ; written without the final dot")
        fwd.append(f"{name}. A {ip}")
        fail.append(ip)
    ips.append(ip)

zone = ["$TTL 3600", "; reverse"] + ptr + ["; forward"] + fwd + [""] + rev_blocks
open(f"{net}/zone.db", "w").write("\n".join(zone) + "\n")
random.shuffle(ips)
open(f"{sb}/senders.txt", "w").write("\n".join(ips) + "\n")
open(f"{net}/expected", "w").write("".join(i + "\n" for i in sorted(fail)))
PY

python3 "$NET/dns_server.py" --zone "$NET/zone.db" --log "$NET/query.log" \
    --port-file "$SANDBOX/dns.port" --daemon \
  || { echo "could not start the DNS server" >&2; exit 1; }

cat > "$SANDBOX/TICKET.txt" <<'EOF'
TICKET-8120  New sender check on the mail relay
-----------------------------------------------
From Monday the relay rejects senders that fail forward-confirmed
reverse DNS (FCrDNS):

  1. the PTR record of the sending IP gives a name, and
  2. that name resolves (A records, following any CNAME) to a list of
     addresses that contains the sending IP again.

Before we switch it on, find which of the regular senders in senders.txt
would be rejected and list their IPs in fcrdns-fail.txt, one per line.
The test resolver with the real records runs on 127.0.0.1, port in dns.port.
EOF
