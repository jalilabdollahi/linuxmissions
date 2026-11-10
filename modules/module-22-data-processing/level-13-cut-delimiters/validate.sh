#!/bin/bash
# payroll.csv = header id,name,amount + one row per D record of payroll.dat,
# in file order: id as written (6 digits), name without the padding, amount
# with the implied decimals made explicit. Read with a CSV parser, so a name
# with a comma must be quoted; quoting other names is allowed.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -s .lm-state/payroll.sum ] || [ "$(cksum < payroll.dat 2>/dev/null)" != "$(cat .lm-state/payroll.sum)" ]; then
  echo "❌ payroll.dat was changed or removed; type 'reset' to restore it"
  exit 1
fi
if [ ! -f payroll.csv ]; then
  echo "❌ payroll.csv does not exist yet"
  exit 1
fi

python3 - <<'PY'
import csv, sys

want = []
with open("payroll.dat", encoding="ascii") as f:
    for line in f:
        line = line.rstrip("\n")
        if line.startswith("D"):
            cents = int(line[45:54])
            want.append([line[1:7], line[7:37].rstrip(" "), "%d.%02d" % (cents // 100, cents % 100)])

def fail(msg):
    print("❌ " + msg)
    sys.exit(1)

raw = open("payroll.csv", encoding="utf-8", errors="replace", newline="").read()
if "\r" in raw:
    fail("payroll.csv has carriage returns (\\r); write plain LF line endings")
rows = list(csv.reader(raw.splitlines()))
rows = [r for r in rows if r != []]
if not rows:
    fail("payroll.csv is empty")
if rows[0] != ["id", "name", "amount"]:
    fail("the first line of payroll.csv must be the header id,name,amount")
got = rows[1:]
if len(got) != len(want):
    fail("payroll.csv has %d data rows, but payroll.dat has %d payment (D) records (the H and T records are not payments)" % (len(got), len(want)))
for n, (g, w) in enumerate(zip(got, want), start=2):
    if len(g) != 3:
        if len(g) == 4 and "," in w[1]:
            fail("line %d splits into 4 columns: the name %s contains a comma, so it must be in double quotes" % (n, '"' + w[1] + '"'))
        fail("line %d of payroll.csv has %d columns, expected 3 (id,name,amount)" % (n, len(g)))
    if g[0] != w[0]:
        if g[0].lstrip("0") == w[0].lstrip("0"):
            fail("line %d: the id lost its leading zeros; keep it as written in the file (%s)" % (n, w[0]))
        fail("line %d: the id %r is not the id of payment %d (columns 2-7)" % (n, g[0], n - 1))
    if g[1] != w[1]:
        if g[1].strip() == w[1]:
            fail("line %d: the name still has padding spaces around it" % n)
        fail("line %d: the name %r is not the beneficiary name of payment %d (columns 8-37, without the padding)" % (n, g[1], n - 1))
    if g[2] != w[2]:
        a = g[2]
        if len(a) > 1 and a[0] == "0" and a[1] != ".":
            fail("line %d: the amount %r still has its zero padding; write it like 123.45" % (n, a))
        try:
            v = float(a)
        except ValueError:
            fail("line %d: the amount %r is not a number" % (n, a))
        cents = int(w[2].replace(".", ""))
        if abs(v - cents) < 0.001:
            fail("line %d: the amount is %s, but the last 2 digits are implied decimals (000012345 means 123.45)" % (n, a))
        if abs(v * 100 - cents) < 0.5:
            fail("line %d: write every amount with exactly two decimals and no padding (%s, not %s)" % (n, w[2], a))
        fail("line %d: the amount %r does not match columns 46-54 of payment %d" % (n, a, n - 1))
print("✅ payroll.csv has all %d payments with clean ids, names and amounts" % len(want))
PY
