#!/bin/bash
# report.txt, byte for byte: header line, rule, one line per team in input
# order (name trimmed, cut to 19 chars + "~" when longer than 20, left in 20
# columns; cost right-aligned in 12 with 2 decimals), rule, TOTAL line.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -s .lm-state/costs.sum ] || [ "$(cksum < costs.csv 2>/dev/null)" != "$(cat .lm-state/costs.sum)" ]; then
  echo "❌ costs.csv was changed or removed; type 'reset' to restore it"
  exit 1
fi
if [ ! -f report.txt ]; then
  echo "❌ report.txt does not exist yet"
  exit 1
fi

python3 - <<'PY'
import sys

def fail(msg):
    print("❌ " + msg)
    sys.exit(1)

rows, total = [], 0.0
for line in open("costs.csv", encoding="utf-8"):
    line = line.rstrip("\n")
    if not line.strip() or line.startswith("#") or line.startswith("team,"):
        continue
    name, cost = line.split(",")
    name = name.strip(" ")
    v = float(cost)
    total += v
    rows.append((name, v))

def cut(n):
    return n if len(n) <= 20 else n[:19] + "~"

rule = "-" * 20 + " " + "-" * 12
want = ["%-20s %12s" % ("TEAM", "COST (USD)"), rule]
want += ["%-20s %12.2f" % (cut(n), v) for n, v in rows]
want += [rule, "%-20s %12.2f" % ("TOTAL", total)]
text = "\n".join(want) + "\n"

got = open("report.txt", encoding="utf-8", errors="replace", newline="").read()
if got == text or got == text.rstrip("\n"):
    print("✅ report.txt is laid out exactly as the cost mail needs it (%d teams, total %.2f)" % (len(rows), total))
    sys.exit(0)
if "\r" in got:
    fail("report.txt has carriage returns (\\r)")
if "\t" in got:
    fail("report.txt has tab characters; mail clients show tabs at different widths, use spaces only")
g = got.rstrip("\n").split("\n")
if len(g) != len(want):
    fail("report.txt has %d lines; expected %d: header, rule, %d teams, rule, TOTAL" % (len(g), len(want), len(rows)))
for i, (a, b) in enumerate(zip(g, want), start=1):
    if a == b:
        continue
    if a.rstrip(" ") == b:
        fail("line %d ends with spaces; no trailing blanks, please" % i)
    if i == 1:
        fail("line 1 must be the header: TEAM left-aligned in 20 columns, a space, then COST (USD) right-aligned in 12")
    if i in (2, len(want) - 1):
        fail("line %d must be the rule: 20 dashes, a space, 12 dashes" % i)
    if len(a) != len(b):
        fail("line %d is %d characters wide, every line must be 33 (20 for the name, 1 space, 12 for the cost)" % (i, len(a)))
    name, num = a[:20], a[21:]
    if name != b[:20]:
        if i == len(want):
            fail("the last line must start with TOTAL, left-aligned in 20 columns")
        full = rows[i - 3][0]
        if name.startswith(" "):
            fail("line %d: the team name starts with spaces; trim the padding that costs.csv has around some names" % i)
        if len(full) > 20 and name.rstrip() == full[:20]:
            fail("line %d: %r is longer than 20 characters; cut it to 19 and add ~ (%s)" % (i, full, full[:19] + "~"))
        if len(full) == 20:
            fail("line %d: %r is exactly 20 characters, so it fits and is not cut" % (i, full))
        fail("line %d: the team name in the first 20 columns should be %r" % (i, b[:20]))
    if num.strip() != b[21:].strip():
        if i == len(want):
            fail("the TOTAL is not the sum of all costs (1e3 is 1000 and the credit is negative)")
        fail("line %d: the cost should be %s (2 decimals; 1e3 means 1000)" % (i, b[21:].strip()))
    fail("line %d: the cost must be right-aligned in its 12 columns" % i)
fail("report.txt is not laid out as required")
PY
