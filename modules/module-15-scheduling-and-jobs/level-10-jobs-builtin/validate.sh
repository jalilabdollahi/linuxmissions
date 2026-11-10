#!/bin/bash
# Expected codes come from the shard data (same rules as import.sh); the
# latest finished run of each shard must overlap the other two in time; and
# statuses.txt must state exactly those codes.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

python3 - <<'PY'
import os
import re
import sys

SHARDS = ("eu", "us", "apac")


def expected(shard):
    try:
        rows = [l.rstrip("\n").split(",") for l in open(f"shards/{shard}.csv")][1:]
    except OSError:
        return 5
    ids = [r[0] for r in rows]
    if len(ids) != len(set(ids)):
        return 4
    if any(len(r) < 3 or r[2] == "" for r in rows):
        return 3
    return 0


runs = {}
for shard in SHARDS:
    last, start = None, None
    try:
        lines = open(f"logs/import-{shard}.log").read().splitlines()
    except OSError:
        lines = []
    for line in lines:
        m = re.match(r"(start|end) \S+ pid=(\d+) ([\d.]+)(?: exit=(\d+))?$", line)
        if not m:
            continue
        if m.group(1) == "start":
            start = (m.group(2), float(m.group(3)))
        elif start and start[0] == m.group(2):
            last = (start[1], float(m.group(3)), int(m.group(4)))
    if last is None:
        print(f"❌ ./import.sh {shard} has not finished a run yet")
        sys.exit(1)
    runs[shard] = last

if max(r[0] for r in runs.values()) >= min(r[1] for r in runs.values()):
    print("❌ the last runs of the three shards did not all run at the same time; start all three as background jobs before you wait for any of them")
    sys.exit(1)

if not os.path.isfile("statuses.txt"):
    print("❌ statuses.txt does not exist yet")
    sys.exit(1)
stated = {}
for line in open("statuses.txt"):
    line = line.strip()
    if not line:
        continue
    m = re.fullmatch(r"(\w+)\s*=\s*(\d+)", line)
    if not m or m.group(1) not in SHARDS:
        print(f"❌ statuses.txt has a line that is not shard=status for eu, us or apac: {line[:40]}")
        sys.exit(1)
    if m.group(1) in stated:
        print(f"❌ statuses.txt names {m.group(1)} twice")
        sys.exit(1)
    stated[m.group(1)] = int(m.group(2))
missing = [s for s in SHARDS if s not in stated]
if missing:
    print(f"❌ statuses.txt has no line for {', '.join(missing)}")
    sys.exit(1)
for shard in SHARDS:
    real = runs[shard][2]
    if real != expected(shard):
        print(f"❌ import.sh {shard} returned {real}, which its data cannot produce; was import.sh changed? (type reset)")
        sys.exit(1)
    if stated[shard] != real:
        print(f"❌ statuses.txt says {shard}={stated[shard]}, but ./import.sh {shard} exited with {real}")
        sys.exit(1)
print("✅ the three shards ran in parallel and statuses.txt has each one's real exit status")
PY
