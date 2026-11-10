#!/bin/bash
# Six-hourly rotated access logs (delaycompress: access.log.1 stays plain).
# daily_report.sh reads access.log.1 twice (by name and again through a
# zcat -f glob) and does not dedupe retried requests by request id.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state
python3 - <<'PY'
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
import random
exp = gen("logs", "2026-11-10", random.SystemRandom().getrandbits(32))
open(".lm-state/expected.txt", "w").write(exp)
PY
cat > daily_report.sh <<'SH'
#!/bin/bash
# Daily KPI report: ./daily_report.sh YYYY-MM-DD   (mailed to finance at 06:00)
cd "$(dirname "$0")" || exit 1
DAY=${1:?usage: daily_report.sh YYYY-MM-DD}
{ cat logs/access.log logs/access.log.1 2>/dev/null; zcat -f logs/access.log.*; } |
  grep "^$DAY" | grep ' POST /checkout 200 ' |
  awk '{ split($7, a, "="); split($8, b, "="); rev += a[2]; n++; u[b[2]] = 1 }
       END { c = 0; for (k in u) c++; printf "date=%s\norders=%d\nrevenue=%.2f\ncustomers=%d\n", day, n, rev, c }' day="$DAY"
SH
chmod 755 daily_report.sh
cat > logrotate.conf <<'CONF'
# changed Monday (ticket OPS-318): rotate every 6 hours, compress later
/var/log/shop/access.log {
    rotate 8
    size 1M
    daily
    delaycompress
    compress
    copytruncate
}
CONF
cat > TICKET.md <<'MD'
# KPI mail shows double revenue

Since Monday morning the daily KPI mail (`./daily_report.sh 2026-11-10`)
shows roughly twice the revenue and order count we see in the payment
dashboard. Monday is also when rotation was changed (logrotate.conf).
Finance only trusts: successful checkouts (POST /checkout answered 200),
each request counted once, revenue summed from the amount field.
Format of a log line: time, client ip, req=ID, method, path, status, amount, user.
MD
