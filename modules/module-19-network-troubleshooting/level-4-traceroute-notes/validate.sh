#!/bin/bash
# Expected values come from mtr-report.txt: the last hop with an address, and
# the first hop whose Avg is > 50 ms above the previous hop that answered.
SANDBOX="$1"

if [ ! -f "$SANDBOX/path.env" ]; then
  echo "❌ path.env does not exist yet"
  exit 1
fi

python3 - "$SANDBOX" <<'PY'
import re, sys
sb = sys.argv[1]
def fail(msg):
    print("❌ " + msg)
    sys.exit(1)

rows = []
for line in open(f"{sb}/mtr-report.txt"):
    m = re.match(r"\s*(\d+)\.\|-- (\S+)\s+(\S+)\s+\d+\s+[\d.]+\s+([\d.]+)", line)
    if m:
        rows.append((int(m.group(1)), m.group(2), float(m.group(4))))
answered = [r for r in rows if r[1] != "???"]
want_last = answered[-1][1]
silent = [r[0] for r in rows if r[1] == "???" and r[0] < answered[-1][0]]
want_jump = next(b[0] for a, b in zip(answered, answered[1:]) if b[2] - a[2] > 50)

got = {}
for raw in open(f"{sb}/path.env", encoding="utf-8", errors="replace"):
    line = raw.strip().replace("\r", "")
    if line and not line.startswith("#"):
        k, _, v = line.partition("=")
        got[k.strip()] = v.strip().strip('"').strip("'")
for k in ("LAST_HOP", "JUMP_HOP"):
    if k not in got:
        fail(f"path.env has no {k}= line")

last = got["LAST_HOP"]
if last != want_last:
    if not re.fullmatch(r"\d+\.\d+\.\d+\.\d+", last):
        fail("LAST_HOP should be an IP address, not a name or hop number")
    ips = {r[1]: r[0] for r in answered}
    if last in ips and silent and ips[last] == silent[0] - 1:
        fail(f"LAST_HOP: the hop after {last} stays silent, but later hops answer again; a hop that drops probes is not where the path ends")
    if last in ips:
        fail(f"LAST_HOP: hop {ips[last]} answers, but it is not the last one that does")
    fail(f"LAST_HOP {last} is not a hop that replied")

jump = got["JUMP_HOP"]
if not jump.isdigit():
    fail("JUMP_HOP should be a hop number")
if int(jump) != want_jump:
    fail(f"JUMP_HOP {jump}: that is not the first hop whose Avg is more than 50 ms above the previous answering hop")
print(f"✅ the path dies after {want_last}; latency jumps at hop {want_jump}")
PY
