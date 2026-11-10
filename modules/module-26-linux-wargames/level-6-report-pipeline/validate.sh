#!/bin/bash
# daily_report.sh gives the exact expected report for the player's logs and
# for a hidden day on a different, freshly generated dataset.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
[ -s .lm-state/expected.txt ] && [ -x daily_report.sh ] || { echo "❌ daily_report.sh or the level data is missing; type 'reset'"; exit 1; }
got=$(./daily_report.sh 2026-11-10 2>&1); rc=$?
exp=$(cat .lm-state/expected.txt)
if [ $rc -ne 0 ]; then echo "❌ daily_report.sh exits $rc: $(echo "$got" | head -1)"; exit 1; fi
if [ "$got" != "$exp" ]; then
  for k in orders revenue customers; do
    g=$(echo "$got" | grep "^$k=" | cut -d= -f2); e=$(echo "$exp" | grep "^$k=" | cut -d= -f2)
    [ "$g" != "$e" ] && { echo "❌ today's report is wrong: $k is $g (finance's number is not that), check how many times each request is counted"; exit 1; }
  done
  echo "❌ today's report does not have the exact expected format"; exit 1
fi
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
day="2026-11-0$((RANDOM % 8 + 1))"
cp daily_report.sh "$TMP/"
cat > "$TMP/gen.py" <<'PY'
import gzip, os, random, sys
from datetime import datetime, timedelta
from decimal import Decimal

def gen(logdir, day, seed, partial_last=True):
    """Six-hourly rotation: .3.gz = D-1 18-24, .2.gz = D 00-06, .1 (plain, delaycompress) = D 06-12, access.log = D 12-now."""
    R = random.Random(seed)
    d0 = datetime.strptime(day, "%Y-%m-%d")
    segs = [(d0 - timedelta(hours=6), d0), (d0, d0 + timedelta(hours=6)), (d0 + timedelta(hours=6), d0 + timedelta(hours=12)),
            (d0 + timedelta(hours=12), d0 + timedelta(hours=17, minutes=40) if partial_last else d0 + timedelta(hours=24))]
    paths = ["access.log.3.gz", "access.log.2.gz", "access.log.1", "access.log"]
    content = [[] for _ in segs]
    orders = {}
    n = 0
    for si, (a, b) in enumerate(segs):
        span = int((b - a).total_seconds())
        for _ in range(R.randint(140, 220)):
            t = a + timedelta(seconds=R.randint(0, span - 1))
            kind = R.choices(["ok", "fail", "cart", "preview", "get"], [55, 10, 12, 12, 11])[0]
            rid = "%08x" % R.getrandbits(32)
            user = "u%d" % R.randint(1000, 1160)
            ip = "10.0.%d.%d" % (R.randint(1, 9), R.randint(2, 250))
            amt = Decimal(R.randint(500, 29900)) / 100
            def line(tt, st, method, path, extra=True):
                return (tt, "%s %s req=%s %s %s %d amount=%s user=%s" % (tt.strftime("%Y-%m-%dT%H:%M:%SZ"), ip, rid, method, path, st, amt if extra else "0.00", user))
            if kind == "ok":
                content[si].append(line(t, 200, "POST", "/checkout"))
                orders[rid] = (t, amt, user)
                if R.random() < 0.09:      # client retry: same request id, replayed 200
                    t2 = t + timedelta(seconds=R.randint(1, 20))
                    tgt = si
                    if si < 3 and (b - t2).total_seconds() <= 0:
                        tgt = si + 1
                    if si == 3 and t2 >= b:
                        continue
                    content[tgt].append(line(t2, 200, "POST", "/checkout"))
            elif kind == "fail":
                content[si].append(line(t, R.choice([500, 402, 502]), "POST", "/checkout", False))
            elif kind == "cart":
                content[si].append(line(t, 200, "GET", "/checkout/cart", False))
            elif kind == "preview":
                content[si].append(line(t, 200, "POST", "/checkout/preview", False))
            else:
                content[si].append(line(t, 200, "GET", "/checkout", False))
    os.makedirs(logdir, exist_ok=True)
    for p, c in zip(paths, content):
        c.sort(key=lambda x: x[0])
        data = ("\n".join(x[1] for x in c) + "\n").encode()
        if p.endswith(".gz"):
            with gzip.open(os.path.join(logdir, p), "wb") as f: f.write(data)
        else:
            open(os.path.join(logdir, p), "wb").write(data)
    mine = {k: v for k, v in orders.items() if v[0].strftime("%Y-%m-%d") == day}
    rev = sum((v[1] for v in mine.values()), Decimal(0))
    return "date=%s\norders=%d\nrevenue=%s\ncustomers=%d\n" % (day, len(mine), rev.quantize(Decimal("0.01")), len(set(v[2] for v in mine.values())))
import random, sys
open(sys.argv[2], "w").write(gen(sys.argv[3] + "/logs", sys.argv[1], int(sys.argv[4]), partial_last=False))
PY
python3 "$TMP/gen.py" "$day" "$TMP/expected" "$TMP" "$RANDOM$$"
got2=$(bash "$TMP/daily_report.sh" "$day" 2>&1); rc=$?
if [ $rc -ne 0 ] || [ "$got2" != "$(cat "$TMP/expected")" ]; then
  echo "❌ today's numbers are right, but a different day's logs (the report must read the logs next to the script and filter by the day it is given) give: $(echo "$got2" | tr '\n' ' ')"; exit 1
fi
echo "✅ the report counts each successful checkout once, for today's logs and for another day"
