#!/bin/bash
# $1 = sandbox path
# Works out the answer from the captures (MACs compared case-insensitively,
# FAILED/INCOMPLETE lines ignored), the inventory and oui.txt, then compares
# conflict.env with it.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

python3 - <<'PY'
import glob, re, sys

def fail(msg):
    print("❌ " + msg)
    sys.exit(1)

seen = {}
for path in sorted(glob.glob("captures/neigh-*.txt")):
    for line in open(path):
        m = re.match(r"(\d+\.\d+\.\d+\.\d+) dev eth0\.30 lladdr ([0-9A-Fa-f:]{17})\b", line)
        if m:
            seen.setdefault(m.group(1), set()).add(m.group(2).lower())
flapping = [ip for ip, macs in seen.items() if len(macs) > 1]
if len(flapping) != 1:
    fail("the captures in captures/ were changed; type 'reset' to get them back")
ip = flapping[0]
inv = {}
for line in open("vlan30-inventory.csv"):
    parts = line.strip().split(",")
    if len(parts) == 3 and parts[0] != "ip":
        inv[parts[0]] = parts[2].lower()
known = inv[ip]
rogue = (seen[ip] - {known}).pop()
vendor = None
for line in open("oui.txt"):
    m = re.match(r"([0-9A-F]{2}-[0-9A-F]{2}-[0-9A-F]{2})\s+\(hex\)\s+(.+)", line)
    if m and m.group(1).replace("-", ":").lower() == rogue[:8]:
        vendor = m.group(2).strip()

try:
    text = open("conflict.env", encoding="utf-8", errors="replace").read()
except FileNotFoundError:
    fail("conflict.env does not exist yet")
got = {}
for line in text.replace("\r", "").splitlines():
    line = line.strip()
    if line.startswith("export "):
        line = line[7:].strip()
    if "=" in line and not line.startswith("#"):
        k, v = line.split("=", 1)
        got[k.strip()] = v.strip().strip("'\"").strip()
for key in ("IP", "KNOWN_MAC", "ROGUE_MAC", "ROGUE_VENDOR"):
    if not got.get(key):
        fail(f"conflict.env has no {key}= line (or it is empty)")

def norm_mac(s):
    return s.lower().replace("-", ":")

if got["IP"] != ip:
    if got["IP"] in seen:
        fail(f"{got['IP']} has the same MAC in every capture once you ignore upper/lower case and FAILED lines")
    fail(f"IP={got['IP']} is not the VLAN 30 address whose MAC changes between captures")
if {norm_mac(got["KNOWN_MAC"]), norm_mac(got["ROGUE_MAC"])} != {known, rogue}:
    fail("IP is right, but KNOWN_MAC/ROGUE_MAC are not the two MACs the captures show for it")
if norm_mac(got["KNOWN_MAC"]) != known:
    fail("KNOWN_MAC and ROGUE_MAC are swapped: the known one is the MAC in vlan30-inventory.csv")
if got["ROGUE_VENDOR"].lower() != vendor.lower():
    fail(f"ROGUE_VENDOR is not the organisation oui.txt lists for the rogue MAC's first three bytes")
print(f"✅ {ip} is claimed by a {vendor} box ({rogue}) as well as its real NIC")
PY
