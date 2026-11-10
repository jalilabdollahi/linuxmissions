#!/bin/bash
# anomalies.csv = header host,date,value,zscore + every numeric value more
# than 3 population standard deviations from its own host's mean (NaN/empty
# left out, hosts with sd 0 have none), sorted by host then date, z with 2
# decimals. detect.sh FILE must print the same for any file of that shape;
# it is also run on a hidden dataset generated here with a fixed seed.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -s .lm-state/requests.sum ] || [ "$(cksum < requests.csv 2>/dev/null)" != "$(cat .lm-state/requests.sum)" ]; then
  echo "❌ requests.csv was changed or removed; type 'reset' to restore it"
  exit 1
fi
if [ ! -f detect.sh ]; then
  echo "❌ detect.sh does not exist yet"
  exit 1
fi
if [ ! -x detect.sh ]; then
  echo "❌ detect.sh is not executable (chmod +x detect.sh)"
  exit 1
fi
if [ ! -f anomalies.csv ]; then
  echo "❌ anomalies.csv does not exist yet (./detect.sh requests.csv > anomalies.csv)"
  exit 1
fi

# The hidden dataset: other hosts, unsorted rows, lowercase nan, a constant
# host, a drop and two spikes. Fixed seed, so the answer never changes.
python3 - <<'PY'
import random
r = random.Random(20261110)
hosts = [("db-01", 5000, 300), ("db-02", 5200, 250), ("cache-01", 80000, 4000), ("cron-01", 288, 0), ("edge-01", 300, 20), ("edge-02", 310, 22)]
rows = []
for d in range(1, 32):
    for h, b, s in hosts:
        v = b if s == 0 else int(round(b + s * (r.random() + r.random() + r.random() - 1.5) * 2))
        rows.append(["2026-12-%02d" % d, h, str(v)])
special = {("db-01", 9): "900", ("cache-01", 20): "140000", ("edge-01", 27): "420", ("db-02", 4): "nan", ("edge-02", 15): "", ("cache-01", 2): "NaN"}
for row in rows:
    k = (row[1], int(row[0][-2:]))
    if k in special:
        row[2] = special[k]
r.shuffle(rows)
with open(".lm-state/hidden.csv", "w") as f:
    f.write("date,host,requests\n")
    for row in rows:
        f.write(",".join(row) + "\n")
PY

# Run the player's script on both files; anything on stderr is a failure
# (a fatal awk error can still leave a plausible-looking partial output).
run() { if command -v timeout >/dev/null; then timeout 20 "$@"; else "$@"; fi; }
run ./detect.sh .lm-state/hidden.csv > .lm-state/hidden.out 2> .lm-state/hidden.err
run ./detect.sh requests.csv > .lm-state/shipped.out 2> .lm-state/shipped.err
for e in .lm-state/shipped.err .lm-state/hidden.err; do
  if [ -s "$e" ] && grep -qi 'division' "$e"; then
    echo "❌ ./detect.sh divides by zero: a host whose value never changes has a standard deviation of 0, and nothing to flag"
    exit 1
  fi
  if [ -s "$e" ]; then
    echo "❌ ./detect.sh printed an error$([ "$e" = .lm-state/hidden.err ] && echo ' on another dataset'): $(head -n 1 "$e" | cut -c1-160)"
    exit 1
  fi
done

python3 - <<'PY'
import math, re, sys

NUM = re.compile(r"^-?[0-9]+(\.[0-9]+)?$")

def fail(msg):
    print("❌ " + msg)
    sys.exit(1)

def detect(path, mode="ok"):
    vals = {}
    for line in open(path, encoding="utf-8").read().splitlines()[1:]:
        d, h, v = line.split(",")
        if not NUM.match(v):
            if mode != "zero":
                continue
            v = "0"
        key = "*" if mode == "global" else h
        vals.setdefault(key, []).append((h, d, v))
    out = []
    for key, items in vals.items():
        xs = [float(v) for _, _, v in items]
        m = sum(xs) / len(xs)
        sd = math.sqrt(sum((x - m) ** 2 for x in xs) / len(xs))
        if sd == 0:
            continue
        for h, d, v in items:
            z = (float(v) - m) / sd
            if abs(z) > 3:
                out.append((h, d, v, z))
    return sorted(out, key=lambda t: (t[0], t[1]))

def parse(text):
    lines = [l for l in text.replace("\r", "").split("\n") if l.strip()]
    if not lines or lines[0] != "host,date,value,zscore":
        return None, "the first line must be the header host,date,value,zscore"
    rows = []
    for l in lines[1:]:
        f = l.split(",")
        if len(f) != 4:
            return None, "every line must be host,date,value,zscore (4 fields): %r" % l
        try:
            z = float(f[3])
        except ValueError:
            return None, "the zscore %r is not a number" % f[3]
        if not re.match(r"^-?[0-9]+\.[0-9]{2}$", f[3]):
            return None, "write the zscore with exactly 2 decimals (e.g. 4.71 or -3.52), not %r" % f[3]
        rows.append((f[0], f[1], f[2], z))
    return rows, None

def same(got, want):
    return len(got) == len(want) and all(g[:3] == w[:3] and abs(g[3] - w[3]) <= 0.011 for g, w in zip(got, want))

def explain(got, path, what):
    want = detect(path)
    if same(got, want):
        return
    keys = lambda rows: sorted(r[:3] for r in rows)
    if keys(got) == keys(want) and not same(sorted(got, key=lambda t: (t[0], t[1])), want):
        fail("%s: the right days, but some zscores are off; use the population standard deviation (divide by n, not n-1) of the host's own values" % what)
    if keys(got) == keys(want):
        fail("%s: sort the lines by host, then by date" % what)
    if any(not NUM.match(r[2]) for r in got) or same(got, detect(path, "zero")):
        fail("%s flags NaN or empty values, or counts them as 0; leave them out of the mean, the deviation and the output" % what)
    if same(got, detect(path, "global")):
        fail("%s uses one mean for all hosts; each host needs its own baseline (a spike on a small host disappears next to web-01)" % what)
    if any(r[3] > 0 for r in want) and not any(r[3] > 0 for r in got) or any(r[3] < 0 for r in want) and not any(r[3] < 0 for r in got):
        fail("%s: more than 3 standard deviations counts in both directions, spikes and drops (|z| > 3)" % what)
    fail("%s lists %d anomalies, but %d values are more than 3 standard deviations from their host's mean" % (what, len(got), len(want)) if len(got) != len(want) else "%s: some lines are not anomalies of their host" % what)

got, err = parse(open("anomalies.csv", encoding="utf-8", errors="replace").read())
if err:
    fail("anomalies.csv: " + err)
explain(got, "requests.csv", "anomalies.csv")

out = open(".lm-state/hidden.out", encoding="utf-8", errors="replace").read()
if not out.strip():
    fail("anomalies.csv is right, but ./detect.sh FILE printed nothing for another file of the same shape; it must read the file named by its first argument ($1) and print to stdout")
got, err = parse(out)
if err:
    fail("on another dataset, detect.sh's output is wrong: " + err)
if got == [] or set(r[0] for r in got) <= {"web-01", "web-02", "api-01", "api-02", "batch-01", "mail-01", "health-01"}:
    fail("anomalies.csv is right, but detect.sh seems to read requests.csv instead of the file given as its first argument ($1)")
want = detect(".lm-state/hidden.csv")
if not same(got, want):
    if any(r[0] == "cron-01" for r in got) or any(math.isnan(r[3]) for r in got):
        fail("on another dataset, detect.sh flags a host whose value never changes; with a standard deviation of 0 there is nothing to flag")
    explain(got, ".lm-state/hidden.csv", "on another dataset (unsorted rows, lowercase nan), detect.sh's output")
print("✅ detect.sh finds the %d anomalies in requests.csv and works on other exports too" % len(detect("requests.csv")))
PY
