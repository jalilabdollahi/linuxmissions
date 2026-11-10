#!/bin/bash
# $1 = sandbox path
# pmtu.txt must be the hidden path MTU, proven by the probe log (a probe of
# PMTU-28 bytes got through, one of PMTU-27 was lost), and the netplan file
# must set wg0's mtu to it with everything else unchanged.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

python3 - <<'PY'
import sys
import yaml

def fail(msg):
    print("❌ " + msg)
    sys.exit(1)

pmtu = min(int(x) for x in open(".vpn/hops") if x.strip())
probes = {}
for line in open(".vpn/probes.log"):
    _, size, result = line.split()
    probes.setdefault(int(size), set()).add(result)

try:
    got = open("pmtu.txt").read().strip()
except FileNotFoundError:
    fail("pmtu.txt does not exist yet")
if not got.isdigit():
    fail("pmtu.txt should contain just one number (bytes)")
got = int(got)
if got == pmtu - 28:
    fail("pmtu.txt has the largest payload that gets through; the MTU counts the whole IP packet (IP + ICMP headers)")
if got != pmtu:
    if got > pmtu:
        fail(f"pmtu.txt says {got}, but a {got}-byte packet doesn't get through the tunnel")
    fail(f"pmtu.txt says {got}, but bigger packets than that get through the tunnel")
if "ok" not in probes.get(pmtu - 28, set()) or not ({"lost", "local"} & probes.get(pmtu - 27, set())):
    fail("pmtu.txt is right, but vpnping never showed it: probe the largest size that passes and the next one up")

try:
    doc = yaml.safe_load(open("netplan/60-vpn.yaml"))
    orig = yaml.safe_load(open(".vpn/orig.yaml"))
    mtu = doc["network"]["tunnels"]["wg0"].get("mtu")
except FileNotFoundError:
    fail("netplan/60-vpn.yaml is missing")
except (yaml.YAMLError, KeyError, TypeError, AttributeError):
    fail("netplan/60-vpn.yaml is no longer valid YAML with network.tunnels.wg0 (check the indentation)")
if mtu != pmtu:
    fail(f"netplan/60-vpn.yaml: wg0's mtu is {mtu}, not the path MTU you found")
doc["network"]["tunnels"]["wg0"]["mtu"] = orig["network"]["tunnels"]["wg0"]["mtu"]
if doc != orig:
    fail("netplan/60-vpn.yaml: change only wg0's mtu, everything else must stay as it was")
print(f"✅ path MTU {pmtu} measured and set on wg0")
PY
