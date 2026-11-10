#!/bin/bash
# report.tsv: departments A-Z, teams A-Z, rows of a team in ledger order;
# amounts as plain numbers with 2 decimals (refunds negative). After each
# team a TEAM TOTAL line, after each department a DEPARTMENT TOTAL line, a
# GRAND TOTAL line at the end. 5 tab-separated columns on every line.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -s .lm-state/ledger.sum ] || [ "$(cksum < ledger.csv 2>/dev/null)" != "$(cat .lm-state/ledger.sum)" ]; then
  echo "❌ ledger.csv was changed or removed; type 'reset' to restore it"
  exit 1
fi
if [ ! -f report.tsv ]; then
  echo "❌ report.tsv does not exist yet"
  exit 1
fi

python3 - <<'PY'
import csv, sys

def fail(msg):
    print("❌ " + msg)
    sys.exit(1)

def cents(s):
    neg = s.startswith("(")
    v = s.strip("()").replace(",", "")
    w, f = v.split(".")
    c = int(w) * 100 + int(f)
    return -c if neg else c

def fmt(c):
    return "%s%d.%02d" % ("-" if c < 0 else "", abs(c) // 100, abs(c) % 100)

recs = list(csv.reader(open("ledger.csv", encoding="utf-8", newline="")))[1:]
groups = {}
for dep, team, date, desc, amt in recs:
    groups.setdefault(dep, {}).setdefault(team, []).append((date, desc, cents(amt)))
want, grand, teamlines = [], 0, {}
for dep in sorted(groups):
    dsum = 0
    for team in sorted(groups[dep]):
        tsum = 0
        for date, desc, c in groups[dep][team]:
            want.append("\t".join([dep, team, date, desc, fmt(c)]))
            tsum += c
        want.append("\t".join([dep, team, "TEAM TOTAL", "", fmt(tsum)]))
        teamlines[len(want)] = (dep, team)
        dsum += tsum
    want.append("\t".join([dep, "", "DEPARTMENT TOTAL", "", fmt(dsum)]))
    grand += dsum
want.append("\t".join(["", "", "GRAND TOTAL", "", fmt(grand)]))

got = open("report.tsv", encoding="utf-8", errors="replace", newline="").read().replace("\r\n", "\n")
g = got.split("\n")
if g and g[-1] == "":
    g.pop()
if g == want:
    print("✅ report.tsv rolls up %d ledger rows into %d team and %d department totals" % (len(recs), len(teamlines), len(groups)))
    sys.exit(0)
if not g:
    fail("report.tsv is empty")
if g[0].startswith("department\t") or g[0].startswith("department,"):
    fail("report.tsv starts with the CSV header; the report has no header line")
bad = [i for i, l in enumerate(g, 1) if l.count("\t") != 4]
if bad:
    fail("line %d of report.tsv does not have 5 tab-separated columns (empty columns still need their tab)" % bad[0])
amts = [l.split("\t")[4] for l in g]
if any("," in a or "(" in a or '"' in a for a in amts):
    fail("some amounts still have quotes, thousands separators or parentheses; write them as plain numbers like 1234.50 and -45.00")
if any(not a.lstrip("-").replace(".", "", 1).isdigit() or "." not in a or len(a.split(".")[1]) != 2 for a in amts):
    fail("every amount needs exactly two decimals (1234.50, -45.00)")
data_want = sorted(l for l in want if "TOTAL" not in l.split("\t")[2])
data_got = sorted(l for l in g if "TOTAL" not in l.split("\t")[2])
if data_got != data_want:
    if len(data_got) != len(data_want):
        fail("report.tsv has %d ledger rows, ledger.csv has %d" % (len(data_got), len(data_want)))
    key = lambda l: l.split("\t")[:4]
    for a, b in zip(sorted(data_got, key=key), sorted(data_want, key=key)):
        if a != b and key(a) == key(b):
            ga, wa = a.split("\t")[4], b.split("\t")[4]
            try:
                gv, wv = float(ga), float(wa)
            except ValueError:
                break
            if abs(gv + wv) < 0.001:
                fail("refunds are written in parentheses: (45.00) means -45.00, but %s %s came out as %s" % (b.split("\t")[2], b.split("\t")[3], ga))
            if abs(wv) >= 1000 and abs(gv - int(abs(wv) / 1000) * (1 if wv > 0 else -1)) < 0.001:
                fail("amounts like \"1,234.50\" contain the delimiter: with -F, the quoted amount is split over two fields, so it became %s" % ga)
            break
    fail("some ledger rows are not copied right: department, team, date, description, then the amount as a plain number")
order_got = [l for l in g if "TOTAL" not in l.split("\t")[2]]
order_want = [l for l in want if "TOTAL" not in l.split("\t")[2]]
if order_got != order_want:
    fail("the ledger rows must be grouped: departments A-Z, teams A-Z inside each department, and inside a team in the order of ledger.csv (a plain sort reorders the rows of a team; sort -s keeps them)")
for i, (a, b) in enumerate(zip(g, want), 1):
    if a != b:
        kind = b.split("\t")[2]
        if kind == "TEAM TOTAL":
            fail("line %d should be the TEAM TOTAL line of %s/%s" % (i, b.split("\t")[0], b.split("\t")[1]) if a.split("\t")[2] != "TEAM TOTAL" else "line %d: the TEAM TOTAL of %s/%s is wrong (refunds count as negative amounts)" % (i, b.split("\t")[0], b.split("\t")[1]))
        if kind == "DEPARTMENT TOTAL":
            fail("line %d should be the DEPARTMENT TOTAL line of %s, right after its last TEAM TOTAL (team column empty)" % (i, b.split("\t")[0]) if a.split("\t")[2] != "DEPARTMENT TOTAL" or a.split("\t")[:2] != b.split("\t")[:2] else "line %d: the DEPARTMENT TOTAL of %s is wrong" % (i, b.split("\t")[0]))
        if kind == "GRAND TOTAL":
            fail("the last line should be the GRAND TOTAL (department and team columns empty) with the sum of all rows" if a.split("\t")[2] != "GRAND TOTAL" or a.split("\t")[:2] != ["", ""] else "the GRAND TOTAL is wrong")
        fail("line %d should be a ledger row of %s/%s, but the totals are not where they belong" % (i, b.split("\t")[0], b.split("\t")[1]))
if len(g) > len(want):
    fail("report.tsv has extra lines after the GRAND TOTAL")
fail("report.tsv is missing lines at the end (the last TEAM TOTAL, DEPARTMENT TOTAL and the GRAND TOTAL come after the last row)")
PY
