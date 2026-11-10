#!/bin/bash
# Works out the expected answer from the capture itself (values are random per
# setup): the one inet address inside 10.20.0.0/22, the label it is assigned
# to, and the state of that interface's header line.
SANDBOX="$1"

if [ ! -f "$SANDBOX/db-iface.env" ]; then
  echo "❌ db-iface.env does not exist yet"
  exit 1
fi

python3 - "$SANDBOX/ip-addr.txt" "$SANDBOX/db-iface.env" <<'PY'
import ipaddress, re, sys

cap, env = sys.argv[1], sys.argv[2]
net = ipaddress.ip_network("10.20.0.0/22")

def fail(msg):
    print("❌ " + msg)
    sys.exit(1)

states, want = {}, None
for line in open(cap, encoding="utf-8"):
    m = re.match(r"^\d+: ([^:@]+)(@\S+)?: <.*> .* state (\S+)", line)
    if m:
        states[m.group(1)] = m.group(3)
    m = re.match(r"^\s+inet (\S+)/\d+ .* (\S+)$", line.rstrip())
    if m and ipaddress.ip_address(m.group(1)) in net:
        want = (m.group(2), m.group(1))
if want is None:
    fail("ip-addr.txt was changed; type reset to get the original capture back")
want_iface, want_addr = want
want_state = states[want_iface]

got = {}
for raw in open(env, encoding="utf-8", errors="replace"):
    line = raw.strip().replace("\r", "")
    if not line or line.startswith("#"):
        continue
    if line.startswith("export "):
        line = line[7:].strip()
    key, sep, val = line.partition("=")
    if not sep:
        fail(f"db-iface.env line '{line}' is not KEY=VALUE")
    got[key.strip()] = val.strip().strip('"').strip("'")

for key in ("IFACE", "ADDR", "STATE"):
    if key not in got:
        fail(f"db-iface.env has no {key}= line")

addr = got["ADDR"]
if "/" in addr:
    fail("ADDR still has its /prefix; the ticket wants the bare address")
try:
    ip = ipaddress.ip_address(addr)
except ValueError:
    fail(f"ADDR={addr} is not an IP address")
if ip not in net:
    fail(f"ADDR={addr} is not inside 10.20.0.0/22 (a /22 is four /24s: which third octets does it cover?)")
if addr != want_addr:
    fail(f"ADDR={addr} is not an address configured on app-07")

iface = got["IFACE"]
if "@" in iface:
    fail(f"IFACE={iface}: the @... part names the parent link, it is not part of the interface name")
if iface != want_iface:
    fail(f"IFACE={iface} is not the interface that carries {addr}")

if got["STATE"] != want_state:
    if got["STATE"].upper() == want_state:
        fail("STATE must be written exactly as ip prints it (upper case)")
    fail(f"STATE={got['STATE']} is not what the capture shows for {iface} (look at its own header line, after 'state')")

print(f"✅ {want_iface} carries {want_addr} in 10.20.0.0/22 and is {want_state}")
PY
