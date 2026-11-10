#!/bin/bash
# Reads firewall.rules the way iptables does (first matching rule in the INPUT
# chain wins, otherwise the chain policy) and pushes test packets through it.
# The fixed ruleset must accept the office on tcp/8443 and treat every other
# packet exactly like the original ruleset did.
SANDBOX="$1"
RULES="$SANDBOX/firewall.rules"

if [ ! -f "$RULES" ]; then
  echo "❌ firewall.rules is missing (type reset to get it back)"
  exit 1
fi

python3 - "$RULES" <<'PY'
import ipaddress, shlex, sys

path = sys.argv[1]
lines = open(path, encoding="utf-8", errors="replace").read().splitlines()

def fail(msg):
    print("❌ " + msg)
    sys.exit(1)

stripped = [l.strip() for l in lines]
if "*filter" not in stripped or "COMMIT" not in stripped:
    fail("firewall.rules must keep its *filter and COMMIT lines, or iptables-restore will reject it")

policy = None
rules = []                       # list of (lineno, dict)
for no, raw in enumerate(lines, 1):
    line = raw.strip()
    if not line or line.startswith("#") or line in ("*filter", "COMMIT"):
        continue
    if line.startswith(":"):
        parts = line[1:].split()
        if parts and parts[0] == "INPUT":
            policy = parts[1] if len(parts) > 1 else None
        continue
    try:
        tok = shlex.split(line)
    except ValueError:
        fail(f"line {no} of firewall.rules has unbalanced quotes")
    if len(tok) < 2 or tok[0] not in ("-A", "-I"):
        fail(f"line {no} of firewall.rules is not a rule iptables-restore understands: {line}")
    chain = tok[1]
    i = 2
    pos = None
    if tok[0] == "-I" and i < len(tok) and tok[i].isdigit():
        pos = int(tok[i]); i += 1
    r = {"line": no}
    while i < len(tok):
        t = tok[i]
        val = tok[i + 1] if i + 1 < len(tok) else None
        if t == "!":
            fail(f"line {no}: this checker does not handle negated matches (!); write the rule without it")
        if t in ("-m", "--match"):
            i += 2; continue
        if t == "--comment" or t == "--reject-with":
            i += 2; continue
        if val is None:
            fail(f"line {no}: option {t} has no value")
        if t in ("-i", "--in-interface"):
            r["iface"] = val
        elif t in ("-s", "--source"):
            try:
                r["src"] = ipaddress.ip_network(val, strict=False)
            except ValueError:
                fail(f"line {no}: {val} is not a valid source address")
        elif t in ("-p", "--protocol"):
            r["proto"] = val.lower()
        elif t in ("--dport", "--destination-port", "--dports", "--destination-ports"):
            ports = []
            for part in val.split(","):
                a, _, b = part.partition(":")
                if not a.isdigit() or (b and not b.isdigit()):
                    fail(f"line {no}: {val} is not a valid port list")
                ports.append((int(a), int(b or a)))
            r["ports"] = ports
        elif t in ("--ctstate", "--state"):
            r["state"] = set(val.upper().split(","))
        elif t in ("-j", "--jump"):
            r["target"] = val.upper()
        else:
            fail(f"line {no}: option {t} is not supported here")
        i += 2
    if "target" not in r:
        fail(f"line {no}: rule has no -j target")
    if r["target"] not in ("ACCEPT", "DROP", "REJECT"):
        fail(f"line {no}: target {r['target']} is not used in this ruleset; use ACCEPT, DROP or REJECT")
    if chain != "INPUT":
        continue
    if pos is None:
        rules.append(r)
    else:
        rules.insert(max(pos - 1, 0), r)

if policy not in ("ACCEPT", "DROP"):
    fail("the INPUT chain policy line (:INPUT DROP [0:0]) is missing or broken")

def verdict(iface, src, proto, dport, state):
    for r in rules:
        if "iface" in r and r["iface"] != iface: continue
        if "src" in r and ipaddress.ip_address(src) not in r["src"]: continue
        if "proto" in r and r["proto"] not in (proto, "all"): continue
        if "ports" in r:
            if dport is None or not any(a <= dport <= b for a, b in r["ports"]): continue
        if "state" in r and state not in r["state"]: continue
        return r["target"]
    return policy

# (description, iface, src, proto, dport, state, expected)
cases = [
    ("a new connection from the office (10.20.4.9) to tcp/8443", "eth0", "10.20.4.9", "tcp", 8443, "NEW", "ACCEPT"),
    ("a new connection from 10.20.4.200 (office) to tcp/8443", "eth0", "10.20.4.200", "tcp", 8443, "NEW", "ACCEPT"),
    ("a connection from the internet (203.0.113.50) to tcp/8443", "eth0", "203.0.113.50", "tcp", 8443, "NEW", "DROP"),
    ("a connection from 10.20.5.9 (not the office) to tcp/8443", "eth0", "10.20.5.9", "tcp", 8443, "NEW", "DROP"),
    ("a connection from the office to tcp/8080 (dev range)", "eth0", "10.20.4.9", "tcp", 8080, "NEW", "DROP"),
    ("a connection from the office to tcp/8442 (dev range)", "eth0", "10.20.4.9", "tcp", 8442, "NEW", "DROP"),
    ("a connection from the office to tcp/8444 (dev range)", "eth0", "10.20.4.9", "tcp", 8444, "NEW", "DROP"),
    ("a connection from the internet to tcp/8000", "eth0", "203.0.113.50", "tcp", 8000, "NEW", "DROP"),
    ("UDP from the internet to port 8443", "eth0", "203.0.113.50", "udp", 8443, "NEW", "DROP"),
    ("SSH from the office", "eth0", "10.20.4.9", "tcp", 22, "NEW", "ACCEPT"),
    ("SSH from another internal network (10.20.9.9)", "eth0", "10.20.9.9", "tcp", 22, "NEW", "ACCEPT"),
    ("SSH from the internet", "eth0", "203.0.113.50", "tcp", 22, "NEW", "DROP"),
    ("a connection from 10.20.9.9 to tcp/8080 (dev range)", "eth0", "10.20.9.9", "tcp", 8080, "NEW", "DROP"),
    ("a connection from 10.20.9.9 to tcp/5000", "eth0", "10.20.9.9", "tcp", 5000, "NEW", "ACCEPT"),
    ("a connection from the internet to tcp/5000", "eth0", "203.0.113.50", "tcp", 5000, "NEW", "DROP"),
    ("HTTP from the internet", "eth0", "203.0.113.50", "tcp", 80, "NEW", "ACCEPT"),
    ("HTTPS from the internet", "eth0", "203.0.113.50", "tcp", 443, "NEW", "ACCEPT"),
    ("MySQL from the office (should be REJECTed)", "eth0", "10.20.4.9", "tcp", 3306, "NEW", "REJECT"),
    ("a reply packet of an established connection", "eth0", "203.0.113.50", "tcp", 51000, "ESTABLISHED", "ACCEPT"),
    ("local traffic on the loopback interface", "lo", "127.0.0.1", "tcp", 5432, "NEW", "ACCEPT"),
    ("ping from the internet", "eth0", "203.0.113.50", "icmp", None, "NEW", "ACCEPT"),
    ("a connection from the internet to tcp/9000", "eth0", "203.0.113.50", "tcp", 9000, "NEW", "DROP"),
]

for desc, iface, src, proto, dport, state, want in cases:
    got = verdict(iface, src, proto, dport, state)
    if got != want:
        if dport == 8443 and want == "ACCEPT":
            fail(f"{desc} would still be {got}")
        fail(f"{desc} would now be {got}; with the original rules it was {want}")

print("✅ the office reaches tcp/8443 and every other packet is treated exactly as before")
PY
