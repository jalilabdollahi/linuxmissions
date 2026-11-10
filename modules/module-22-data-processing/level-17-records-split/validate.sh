#!/bin/bash
# by_region/ = exactly one file per region of all_orders.csv, named after the
# region with "/" -> "-" and " " -> "_" plus .csv, each with the header and
# that region's rows in source order. Nothing else in the directory.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -s .lm-state/orders.sum ] || [ "$(cksum < all_orders.csv 2>/dev/null)" != "$(cat .lm-state/orders.sum)" ]; then
  echo "❌ all_orders.csv was changed or removed; type 'reset' to restore it"
  exit 1
fi
if [ ! -d by_region ]; then
  echo "❌ the directory by_region/ is gone; create it again and put one file per region in it"
  exit 1
fi

python3 - <<'PY'
import os, sys

def fail(msg):
    print("❌ " + msg)
    sys.exit(1)

lines = open("all_orders.csv", encoding="utf-8").read().splitlines()
header, rows = lines[0], lines[1:]
want = {}
for r in rows:
    region = r.split(",")[2]
    name = region.replace("/", "-").replace(" ", "_") + ".csv"
    want.setdefault(name, (region, []))[1].append(r)

entries = []
for root, dirs, files in os.walk("by_region"):
    for f in files:
        entries.append(os.path.relpath(os.path.join(root, f), "by_region"))
for d in os.listdir("by_region"):
    if os.path.isdir(os.path.join("by_region", d)):
        fail("by_region/ contains a directory (%s/): a / in the region name must become -, so EU/West goes to EU-West.csv" % d)
if "Benelux.csv" in entries:
    fail("by_region/Benelux.csv is last month's file; that region no longer exists, so remove it")
for e in sorted(entries):
    if e not in want:
        if " " in e:
            fail("by_region/%s has a space in its name; spaces in a region name become _ (Asia Pacific -> Asia_Pacific.csv)" % e)
        fail("by_region/%s is not one of the expected files (one per region: / becomes -, spaces become _, then .csv)" % e)
for name in sorted(want):
    if name not in entries:
        fail("by_region/%s is missing (the rows of region %s)" % (name, want[name][0]))

total = 0
for name, (region, rws) in sorted(want.items()):
    raw = open(os.path.join("by_region", name), encoding="utf-8", errors="replace").read()
    got = raw.splitlines()
    total += max(len(got) - 1, 0)
    if not got or got[0] != header:
        fail("by_region/%s must start with the header line of all_orders.csv" % name)
    if got.count(header) > 1:
        fail("by_region/%s has the header line %d times; it belongs only at the top, even when a region comes back later in the file" % (name, got.count(header)))
    if "ORD-30412,2026-09-03,EU/West,Hagen Werkzeuge GmbH,812.40" in got:
        fail("by_region/%s still has last month's rows: >> appended to the old file; start from an empty file" % name)
    if got[1:] != rws:
        if sorted(got[1:]) == sorted(rws):
            fail("by_region/%s has the right rows, but not in the order of all_orders.csv" % name)
        fail("by_region/%s has %d data rows; region %s has %d in all_orders.csv" % (name, len(got) - 1, region, len(rws)) if len(got) - 1 != len(rws) else "by_region/%s has rows that are not the %s rows of all_orders.csv" % (name, region))
    if not raw.endswith("\n"):
        fail("by_region/%s does not end with a newline" % name)
print("✅ %d regional files, %d rows in total, the same as all_orders.csv" % (len(want), len(rows)))
PY
