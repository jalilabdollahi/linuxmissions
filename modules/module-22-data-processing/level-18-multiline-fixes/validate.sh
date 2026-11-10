#!/bin/bash
# tickets_flat.csv must hold the same records as tickets.csv (read with a real
# CSV parser) with every newline inside a field turned into one space, one
# record per line. count.txt = number of tickets (records without the header).
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -s .lm-state/tickets.sum ] || [ "$(cksum < tickets.csv 2>/dev/null)" != "$(cat .lm-state/tickets.sum)" ]; then
  echo "❌ tickets.csv was changed or removed; type 'reset' to restore it"
  exit 1
fi
for f in tickets_flat.csv; do
  if [ ! -f "$f" ]; then
    echo "❌ $f does not exist yet"
    exit 1
  fi
done

python3 - <<'PY'
import csv, io, sys

def fail(msg):
    print("❌ " + msg)
    sys.exit(1)

with open("tickets.csv", encoding="utf-8", newline="") as f:
    want = [[x.replace("\n", " ") for x in rec] for rec in csv.reader(f)]
tickets = len(want) - 1

raw = open("tickets_flat.csv", encoding="utf-8", errors="replace", newline="").read()
if "\r" in raw:
    fail("tickets_flat.csv contains carriage returns (\\r)")
lines = raw.split("\n")
if lines and lines[-1] == "":
    lines.pop()
try:
    got = list(csv.reader(io.StringIO(raw, newline=""), strict=True))
except csv.Error as e:
    fail("tickets_flat.csv is not valid CSV (%s); keep the quotes as they are" % e)
if len(got) != len(lines):
    multi = len(lines) - len(got)
    fail("tickets_flat.csv still has %d line break(s) inside quoted fields; every record must be on one line" % multi)
if len(got) != len(want):
    fail("tickets_flat.csv has %d records, tickets.csv has %d (header included)" % (len(got), len(want)))
if got[0] != want[0]:
    fail("the first line of tickets_flat.csv must be the header of tickets.csv")
for g, w in zip(got[1:], want[1:]):
    if g != w:
        if len(g) != len(w):
            fail("the record of %s has %d fields instead of %d: a quote or a comma inside a field was changed" % (w[0], len(g), len(w)))
        for name, a, b in zip(want[0], g, w):
            if a != b:
                if a.replace(" ", "") == b.replace(" ", ""):
                    fail("%s: the %s field has the wrong spaces; each line break becomes exactly one space, nothing else changes" % (w[0], name))
                fail("%s: the %s field is not the same as in tickets.csv" % (w[0], name))

import os
if not os.path.isfile("count.txt"):
    fail("tickets_flat.csv is right; count.txt does not exist yet")
c = open("count.txt", encoding="utf-8", errors="replace").read().strip()
if c != str(tickets):
    if c.isdigit():
        fail("count.txt says %s, but the export has a different number of tickets (the header is not a ticket)" % c)
    fail("count.txt must contain just the number of tickets")
print("✅ tickets_flat.csv has all %d tickets on one line each" % tickets)
PY
