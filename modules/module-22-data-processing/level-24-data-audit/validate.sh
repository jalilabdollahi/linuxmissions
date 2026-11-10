#!/bin/bash
# audit.txt, four sections in this order (blank lines ignored):
#   [missing]     ids in source.csv but not in loaded.tsv
#   [duplicated]  ids that occur more than once in loaded.tsv (each once)
#   [changed]     "id source_amount loaded_amount" where the loaded amount differs
#   [totals]      "source X" and "loaded Y" (every loaded row counts)
# ids lowercase as in source.csv and sorted, amounts with 2 decimals.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -s .lm-state/inputs.sum ] || [ "$(cat source.csv loaded.tsv 2>/dev/null | cksum)" != "$(cat .lm-state/inputs.sum)" ]; then
  echo "❌ source.csv or loaded.tsv was changed or removed; type 'reset' to restore them"
  exit 1
fi
if [ ! -f audit.txt ]; then
  echo "❌ audit.txt does not exist yet"
  exit 1
fi

python3 - <<'PY'
import csv, sys

def fail(msg):
    print("❌ " + msg)
    sys.exit(1)

def cents(s):
    w, _, f = s.partition(".")
    return int(w) * 100 + int((f + "00")[:2])

def fmt(c):
    return "%s%d.%02d" % ("-" if c < 0 else "", abs(c) // 100, abs(c) % 100)

src, commas = {}, set()
for row in list(csv.reader(open("source.csv", encoding="utf-8", newline="")))[1:]:
    src[row[0]] = cents(row[2])
    if "," in row[1]:
        commas.add(row[0])
loaded, count = {}, {}
for line in open("loaded.tsv", encoding="utf-8").read().splitlines()[1:]:
    f = line.split("\t")
    i = f[0].lower()
    count[i] = count.get(i, 0) + 1
    loaded.setdefault(i, []).append(int(f[2]))

want = {
    "missing": sorted(i for i in src if i not in count),
    "duplicated": sorted(i for i in count if count[i] > 1),
    "changed": ["%s %s %s" % (i, fmt(src[i]), fmt(loaded[i][0])) for i in sorted(src) if i in loaded and loaded[i][0] != src[i]],
    "totals": ["source " + fmt(sum(src.values())), "loaded " + fmt(sum(sum(v) for v in loaded.values()))],
}
# what a truncating cents conversion (int(x * 100)) would call "changed"
trunc = sorted(i for i in src if i in loaded and int(float(fmt(src[i])) * 100) != src[i])

order = ["missing", "duplicated", "changed", "totals"]
lines = [l.strip() for l in open("audit.txt", encoding="utf-8", errors="replace").read().replace("\r", "").split("\n") if l.strip()]
heads = [l for l in lines if l.startswith("[")]
if heads != ["[%s]" % s for s in order]:
    fail("audit.txt needs the four section headers [missing], [duplicated], [changed], [totals], each once and in that order")
got, cur = {}, None
for l in lines:
    if l.startswith("["):
        cur = l[1:-1]
        got[cur] = []
    else:
        got[cur].append(" ".join(l.split()))
if any(ch.isupper() for s in order[:3] for l in got[s] for ch in l.split()[0]):
    fail("write the invoice ids as source.csv does (inv-004213), not as the loader does (INV-004213)")

for sec in order:
    g, w = got[sec], want[sec]
    if g == w:
        continue
    if sec in ("missing", "duplicated", "changed") and sorted(g) == sorted(w):
        fail("[%s] has the right lines; sort them by invoice id" % sec)
    if sec == "missing":
        if not g:
            fail("[missing] is empty, but some invoices never arrived: equal row counts don't prove anything when other rows were loaded twice")
        if set(g) == set(want["duplicated"]):
            fail("[missing] lists the duplicated ids; missing means in source.csv but not in loaded.tsv at all")
        fail("[missing] should list every invoice id of source.csv that is not in loaded.tsv (%d found, %d expected)" % (len(g), len(w)))
    if sec == "duplicated":
        if len(g) != len(set(g)):
            fail("[duplicated]: list each duplicated id once")
        fail("[duplicated] should list every id that occurs more than once in loaded.tsv (%d found, %d expected)" % (len(g), len(w)))
    if sec == "changed":
        if any(len(l.split()) != 3 for l in g):
            fail("every [changed] line must be: id source_amount loaded_amount (e.g. inv-004213 1520.00 1502.00)")
        ids = [l.split()[0] for l in g]
        if [l.split()[0] for l in w] == ids:
            fail("[changed] has the right ids, but the amounts must be written in units with 2 decimals (loaded.tsv has cents: 152000 is 1520.00)")
        extra = set(ids) - set(l.split()[0] for l in w)
        if extra and extra <= set(trunc):
            fail("[changed] lists invoices whose amount did not change: converting 1.15 to cents with int(1.15 * 100) gives 114 because of floating point; round instead (sprintf \"%.0f\")")
        if extra & commas:
            fail("[changed] lists invoices of customers like \"Acme, Inc.\": the comma inside the quoted name shifts the fields, so $3 is not the amount there (the amount is always the last field, $NF)")
        if extra & set(want["missing"]):
            fail("[changed] lists missing invoices; an invoice that was never loaded belongs only in [missing]")
        fail("[changed] should list the %d invoices whose loaded amount differs from source.csv (%d listed)" % (len(w), len(g)))
    if sec == "totals":
        if len(g) != 2 or not g[0].startswith("source ") or not g[1].startswith("loaded "):
            fail("[totals] must have two lines: source <total> and loaded <total>, both with 2 decimals")
        if g[0] != w[0]:
            fail("the source total is not the sum of source.csv's amounts (the amount is the last field; some customer names contain a comma)")
        dedup = "loaded " + fmt(sum(v[0] for v in loaded.values()))
        if g[1] == dedup:
            fail("the loaded total must count every row of loaded.tsv, duplicates included: that is what finance sees in the warehouse")
        fail("the loaded total is not the sum of loaded.tsv's AMOUNT_CENTS column, in units with 2 decimals")
print("✅ audit.txt explains the difference: %d missing, %d duplicated, %d changed" % (len(want["missing"]), len(want["duplicated"]), len(want["changed"])))
PY
