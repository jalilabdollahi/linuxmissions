#!/bin/bash
# $1 = sandbox path
# Routes every flow in flows.txt the way the kernel does: rules in priority
# order (from/to selectors), longest prefix inside the chosen table, lowest
# metric on a tie, fall through to the next rule when the table has no
# match. Then compares flows.tsv line by line.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

python3 - <<'PY'
import ipaddress as ipa, re, sys

def fail(msg):
    print("❌ " + msg)
    sys.exit(1)

def net(s):
    return ipa.ip_network("0.0.0.0/0" if s in ("all", "default") else s, strict=False)

rules = []
for line in open("ip-rule.txt"):
    m = re.match(r"(\d+):\s+from (\S+)(?: to (\S+))? lookup (\S+)", line)
    if m:
        rules.append((int(m.group(1)), net(m.group(2)), net(m.group(3) or "all"), m.group(4)))
rules.sort()
tables = {}
for line in open("ip-route-all.txt"):
    w = line.split()
    if not w or w[0] in ("local", "broadcast", "laptop-jk$"):
        continue
    kv = {w[i]: w[i + 1] for i in range(1, len(w) - 1)}
    tables.setdefault(kv.get("table", "main"), []).append(
        (net(w[0]), kv.get("via", "direct"), kv["dev"], int(kv.get("metric", 0))))

def route(src, dst):
    skipped = False          # a matching rule whose table had no route
    for _, frm, to, table in rules:
        if src in frm and dst in to:
            cands = [rt for rt in tables.get(table, []) if dst in rt[0]]
            if cands:
                best = max(cands, key=lambda rt: (rt[0].prefixlen, -rt[3]))
                return best[1], best[2], table, skipped, best[0].prefixlen == 0
            skipped = skipped or table != "local"
    return None

flows = []
for line in open("flows.txt"):
    if line.strip() and not line.startswith("#"):
        s, d = line.split()[:2]
        flows.append((s, d, route(ipa.ip_address(s), ipa.ip_address(d))))

try:
    rows = [l.split() for l in open("flows.tsv", encoding="utf-8", errors="replace").read().replace("\r", "").splitlines() if l.strip()]
except FileNotFoundError:
    fail("flows.tsv does not exist yet")
if len(rows) != len(flows):
    fail(f"flows.tsv has {len(rows)} lines, flows.txt has {len(flows)} flows")
for n, (row, (s, d, (gw, dev, table, skipped, is_default))) in enumerate(zip(rows, flows), 1):
    if len(row) != 4:
        fail(f"line {n} of flows.tsv should have 4 fields: source destination gateway device")
    if row[0] != s or row[1] != d:
        fail(f"line {n} of flows.tsv is not '{s} {d}' (keep the order of flows.txt)")
    if row[2] != gw or row[3] != dev:
        if skipped:
            why = "a rule matched this flow, but does its table have a route for the destination?"
        elif table != "main":
            why = "check the rules in priority order: one of them sends this flow to another table before main"
        elif is_default:
            why = "two default routes: the source address doesn't choose between them"
        else:
            why = "look for the longest matching prefix in the table that is used"
        fail(f"flow {n} ({s} -> {d}): '{row[2]} {row[3]}' is wrong; {why}")
print(f"✅ all {len(flows)} flows routed like the kernel would")
PY
