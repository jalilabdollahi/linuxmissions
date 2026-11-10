#!/bin/bash
# $1 = sandbox path
# Reads the counters from both captures (carrier transitions = transns, CRC)
# and duplex from sysfs-net.txt, then compares link.env with them.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

python3 - <<'PY'
import re, sys

def fail(msg):
    print("❌ " + msg)
    sys.exit(1)

def counters(path):
    out, cur, lines = {}, None, open(path).read().splitlines()
    for i, line in enumerate(lines):
        m = re.match(r"\d+: ([\w.]+):", line)
        if m:
            cur = m.group(1)
            out[cur] = {}
        elif cur and line.strip().startswith("RX errors:"):
            out[cur]["crc"] = int(lines[i + 1].split()[1])
        elif cur and line.strip().startswith("TX errors:"):
            out[cur]["transns"] = int(lines[i + 1].split()[4])
    return out

try:
    a, b = counters("ip-link-1402.txt"), counters("ip-link-1403.txt")
    duplex = dict(re.findall(r"^/sys/class/net/([\w.]+)/duplex:(\w+)$", open("sysfs-net.txt").read(), re.M))
except (OSError, IndexError, ValueError):
    fail("the capture files were changed; type 'reset' to get them back")
flap = [n for n in a if b[n]["transns"] != a[n]["transns"]]
half = [n for n, v in duplex.items() if v == "half"]
if len(flap) != 1 or len(half) != 1:
    fail("the capture files were changed; type 'reset' to get them back")
flap, half = flap[0], half[0]
crc_delta = b[flap]["crc"] - a[flap]["crc"]
worst_crc = max(a, key=lambda n: b[n]["crc"])

try:
    text = open("link.env", encoding="utf-8", errors="replace").read()
except FileNotFoundError:
    fail("link.env does not exist yet")
got = {}
for line in text.replace("\r", "").splitlines():
    line = line.strip()
    if "=" in line and not line.startswith("#"):
        k, v = line.split("=", 1)
        got[k.strip()] = v.strip().strip("'\"")
for key in ("FLAPPING", "DUPLEX_MISMATCH", "CRC_DELTA"):
    if not got.get(key):
        fail(f"link.env has no {key}= line (or it is empty)")
if got["FLAPPING"] != flap:
    if got["FLAPPING"] == worst_crc:
        fail(f"FLAPPING: {worst_crc} has the most errors in total, but did its counters move between the two captures?")
    fail(f"FLAPPING: {got['FLAPPING']} is not the interface whose carrier went down and up between the captures")
if got["DUPLEX_MISMATCH"] != half:
    if duplex.get(got["DUPLEX_MISMATCH"]) == "unknown":
        fail(f"DUPLEX_MISMATCH: {got['DUPLEX_MISMATCH']} is administratively down, so 'unknown' is normal there")
    fail(f"DUPLEX_MISMATCH: {got['DUPLEX_MISMATCH']} is not the interface running at the wrong duplex")
if got["CRC_DELTA"] != str(crc_delta):
    if got["CRC_DELTA"] == str(b[flap]["crc"]):
        fail("CRC_DELTA is the total CRC count; the ticket wants how many arrived between the two captures")
    fail(f"CRC_DELTA is not the difference between {flap}'s crc counters in the two captures")
print(f"✅ {flap} is flapping (+{crc_delta} CRC errors in 60 s) and {half} runs at half duplex")
PY
