#!/bin/bash
# Wargame 19: reconcile CSV invoices (units, mixed currencies) with a fixed-width
# provider file (EUR cents), using the latest rate on or before each invoice date.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
rm -rf invoices.csv rates.csv provider.txt FORMAT.md mismatch.csv .lm
mkdir -p .lm
cat > FORMAT.md <<'MD'
invoices.csv   CSV with header: id,date,currency,amount
               id like INV-00042, date YYYY-MM-DD, amount in currency units (1234.56)
rates.csv      CSV with header: date,currency,rate
               rate = EUR for 1 unit of the currency, valid from that date until the
               next row for the same currency. EUR itself has no rows (rate 1).
provider.txt   fixed width, no separators:
               columns  1- 9  invoice id
               columns 10-17  settlement date YYYYMMDD
               columns 18-29  settled amount in EUR CENTS, zero padded
               columns 30-40  padding
MD
python3 - <<'PY'
import os, random
from decimal import Decimal, ROUND_HALF_UP
from datetime import date, timedelta
rnd = random.Random(os.urandom(8))
cur = {"USD": Decimal("0.9100"), "GBP": Decimal("1.1500"), "CHF": Decimal("1.0400")}
rates = []   # (date, cur, rate)
start = date(2026, 9, 25)
for c, base in cur.items():
    d = start - timedelta(days=rnd.randint(0, 3)); r = base
    while d < date(2026, 11, 6):
        rates.append((d, c, r))
        d += timedelta(days=rnd.randint(2, 7))
        r = (r + Decimal(rnd.randint(-250, 250)) / 10000).quantize(Decimal("0.0001"))
rates.sort(key=lambda x: (x[0], x[1]))
def rate_for(c, d):
    if c == "EUR": return Decimal(1)
    best = None
    for rd, rc, rr in rates:
        if rc == c and rd <= d: best = rr
    return best
latest = {c: [r for _, rc, r in rates if rc == c][-1] for c in cur}
inv = []; ids = list(range(1, 261)); rnd.shuffle(ids)
rows = []; prov = []; mism = []
for n in ids:
    d = date(2026, 10, 1) + timedelta(days=rnd.randint(0, 29))
    c = rnd.choice(["USD", "USD", "GBP", "CHF", "EUR", "EUR"])
    while True:
        cents_in = rnd.randint(2000, 900000)
        val = Decimal(cents_in) * rate_for(c, d)
        frac = val - val.to_integral_value(rounding="ROUND_FLOOR")
        if Decimal("0.35") < frac < Decimal("0.65"): continue
        break
    eur = int(val.quantize(Decimal(1), rounding=ROUND_HALF_UP))
    pid = eur
    if rnd.random() < 0.13:
        pid = eur + rnd.choice([-1, 1]) * rnd.randint(2, 400)
    iid = f"INV-{n:05d}"
    rows.append((iid, d.isoformat(), c, f"{cents_in // 100}.{cents_in % 100:02d}"))
    prov.append(f"{iid}{(d + timedelta(days=rnd.randint(0,2))).strftime('%Y%m%d')}{pid:012d}".ljust(40))
    if abs(pid - eur) > 1: mism.append((iid, eur, pid))
rnd.shuffle(rows); rnd.shuffle(prov)
with open("invoices.csv", "w") as f:
    f.write("id,date,currency,amount\n")
    for r in rows: f.write(",".join(r) + "\n")
with open("rates.csv", "w") as f:
    f.write("date,currency,rate\n")
    for d, c, r in rates: f.write(f"{d.isoformat()},{c},{r}\n")
open("provider.txt", "w").write("\n".join(prov) + "\n")
mism.sort()
with open(".lm/mismatch.csv", "w") as f:
    f.write("invoice,invoice_eur,provider_eur\n")
    for iid, e, p in mism: f.write(f"{iid},{e//100}.{e%100:02d},{p//100}.{p%100:02d}\n")
PY
exit 0
