#!/bin/bash
# Longest-prefix match over routes.txt for every destination, compared with
# answers.tsv line by line.
SANDBOX="$1"

if [ ! -f "$SANDBOX/answers.tsv" ]; then
  echo "❌ answers.tsv does not exist yet"
  exit 1
fi

python3 - "$SANDBOX" <<'PY'
import ipaddress, sys, os

sb = sys.argv[1]
def fail(msg):
    print("❌ " + msg)
    sys.exit(1)

routes = []
for line in open(os.path.join(sb, "routes.txt")):
    w = line.split()
    if not w:
        continue
    net = ipaddress.ip_network("0.0.0.0/0" if w[0] == "default" else w[0])
    gw = w[w.index("via") + 1] if "via" in w else "direct"
    routes.append((net, gw, w[w.index("dev") + 1]))

dests = open(os.path.join(sb, "destinations.txt")).read().split()
rows = []
for raw in open(os.path.join(sb, "answers.tsv"), encoding="utf-8", errors="replace"):
    w = raw.replace("\r", "").split()
    if w:
        rows.append(w)

if len(rows) != len(dests):
    fail(f"answers.tsv has {len(rows)} lines, destinations.txt has {len(dests)}")

for d, row in zip(dests, rows):
    if len(row) != 3:
        fail(f"line '{' '.join(row)}' should have three columns: DESTINATION GATEWAY INTERFACE")
    if row[0] != d:
        fail(f"line for {row[0]}: expected the destinations in the order of destinations.txt ({d} comes here)")
    ip = ipaddress.ip_address(d)
    covering = [r for r in routes if ip in r[0]]
    best = max(covering, key=lambda r: r[0].prefixlen)
    got = (row[1].lower() if row[1].lower() == "direct" else row[1], row[2])
    if got == (best[1], best[2]):
        continue
    first = covering[0]
    if got == (first[1], first[2]) and first != best:
        fail(f"{d}: that is the first route in the table that covers it, but the kernel picks the most specific one")
    if got[0] == "direct" and best[1] != "direct":
        fail(f"{d}: it is not on a directly connected network, so it needs a gateway")
    fail(f"{d}: gateway/interface is not what jh-02 would use")

print("✅ every destination has the gateway and interface the kernel would pick")
PY
