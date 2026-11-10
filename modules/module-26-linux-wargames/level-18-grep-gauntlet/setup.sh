#!/bin/bash
# Wargame 18: find every trace of one order across five services' logs.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
rm -rf logs .lm trail.txt TICKET.txt
mkdir -p logs .lm
python3 - "$SANDBOX" <<'PY'
import gzip, os, random, sys, uuid
sb = sys.argv[1]
rnd = random.Random(os.urandom(8))
U = str(uuid.UUID(int=rnd.getrandbits(128), version=4))
near = U[:-1] + ("0" if U[-1] != "0" else "1")
same_prefix = U[:8] + "-" + str(uuid.UUID(int=rnd.getrandbits(128), version=4))[9:]
nodash, upper, enc = U.replace("-", ""), U.upper(), U.replace("-", "%2D")
other = lambda: str(uuid.UUID(int=rnd.getrandbits(128), version=4))
open(f"{sb}/TICKET.txt", "w").write(
    f"Ticket SUP-4471\nCustomer: order {U} failed around 14:00 yesterday (2026-11-09) at checkout.\n"
    "Please send engineering everything the services logged about it.\n")

def ts(day, h, m, s, ms=None):
    base = f"2026-11-{day:02d}T{h:02d}:{m:02d}:{s:02d}"
    full = base + f".{ms:03d}Z" if ms is not None else base
    return full, full

def gw_stamp(day, h, m, s):
    return f"{day:02d}/Nov/2026:{h:02d}:{m:02d}:{s:02d} +0000"

# each file: list of (sortkey, line); order lines are flagged
files = {}
def noise(service, day, h0, h1, n):
    out = []
    for _ in range(n):
        h = rnd.randint(h0, h1); m = rnd.randint(0, 59); s = rnd.randint(0, 59); ms = rnd.randint(0, 999)
        key, iso = ts(day, h, m, s, ms)
        oid = other()
        if service == "gateway":
            line = f'10.0.{rnd.randint(0,9)}.{rnd.randint(2,200)} - - [{gw_stamp(day,h,m,s)}] "{rnd.choice(["GET","POST"])} /orders/{oid}/status HTTP/1.1" {rnd.choice([200,200,200,304,404])} {rnd.randint(120,4000)}'
            key = key
        elif service == "orders":
            line = f"{iso} INFO order.{rnd.choice(['created','updated','shipped'])} id={oid} items={rnd.randint(1,6)}"
        elif service == "payments":
            line = f"{iso} INFO payment.{rnd.choice(['authorized','captured','refunded'])} order={oid} amount={rnd.randint(5,900)}.{rnd.randint(0,99):02d}"
        elif service == "inventory":
            line = f"{iso} DEBUG stock.reserve ref={oid.replace('-','')} sku=SKU-{rnd.randint(1000,9999)} qty={rnd.randint(1,4)}"
        else:
            line = f"{iso} INFO mail.sent template=receipt order={oid} to=customer{rnd.randint(1,9999)}@example.net"
        out.append((key, line))
    # sprinkle decoys that look like the order but are not
    if day == 9 and h0 >= 12:
        key, iso = ts(day, 13, rnd.randint(50, 59), rnd.randint(0, 59), rnd.randint(0, 999))
        out.append((key, f"{iso} WARN {service} lookup miss for order {near}"))
        key, iso = ts(day, 14, rnd.randint(0, 9), rnd.randint(0, 59), rnd.randint(0, 999))
        out.append((key, f"{iso} INFO {service} batch ref {same_prefix} reconciled"))
    out.sort()
    return out

services = ["gateway", "orders", "payments", "inventory", "notify"]
for sv in services:
    files[f"{sv}.log.2.gz"] = noise(sv, 9, 6, 11, 90)
    files[f"{sv}.log.1"] = noise(sv, 9, 12, 23, 130)
    files[f"{sv}.log"] = noise(sv, 10, 0, 8, 60)

hits = []   # (sortkey, line, file)
def add(fname, key, line, pos=None):
    hits.append((key, line))
    files[fname].append((key, line)) if pos is None else files[fname].insert(pos, (key, line))
d = rnd.randint(0, 40)
t = lambda m, s: (13, 58 + (m), s)
k, iso = ts(9, 9, 12, 41, 118);  add("orders.log.2.gz", k, f"{iso} INFO order.created id={U} items=3 channel=web")
k, iso = ts(9, 13, 58, 1, 204)
add("gateway.log.1", "2026-11-09T13:58:01", f'10.0.3.{rnd.randint(2,200)} - - [{gw_stamp(9,13,58,1)}] "POST /checkout/confirm?ref={enc}&retry=0 HTTP/1.1" 502 187')
k, iso = ts(9, 13, 58, 2, 377); add("orders.log.1", k, f"{iso} INFO order.submit id={U} total=129.90")
k, iso = ts(9, 13, 58, 2, 951); add("inventory.log.1", k, f"{iso} DEBUG stock.reserve ref={nodash} sku=SKU-4410 qty=1")
k, iso = ts(9, 13, 58, 4, 12);  add("payments.log.1", k, f"{iso} ERROR payment.declined ORDER={upper} code=card_expired")
k, iso = ts(9, 13, 58, 4, 640); add("orders.log.1", k, f"{iso} ERROR order.failed id={U} reason=payment_declined")
k, iso = ts(9, 13, 59, 30, 5)
add("payments.log.1", k, f"{iso} WARN payment.retry order={U} attempt=2")   # appended out of order below
k, iso = ts(9, 14, 0, 5, 880);  add("notify.log.1", k, f"{iso} ERROR mail.failed template=order_failed order={U} smtp=451")
add("gateway.log.1", "2026-11-09T14:00:09", f'10.0.3.{rnd.randint(2,200)} - - [{gw_stamp(9,14,0,9)}] "GET /orders/{U}/status HTTP/1.1" 200 412')
add("gateway.log", "2026-11-10T08:29:44", f'10.0.7.{rnd.randint(2,200)} - - [{gw_stamp(10,8,29,44)}] "GET /orders/{enc.replace("%2D","-")}/status HTTP/1.1" 200 412')
k, iso = ts(10, 8, 31, 2, 77);  add("orders.log", k, f"{iso} INFO support.lookup id={U} agent=sam")

# one payments line lands out of order in the file (buffered writer)
pl = files["payments.log.1"]
late = [x for x in pl if x[0] == "2026-11-09T13:59:30.005Z"][0]
pl.remove(late)
pl.insert(len(pl) - 3, late)
for name in files:
    if name.endswith(".gz") or name.endswith(".log") or name.endswith(".1"):
        pass
    if name not in ("payments.log.1",):
        files[name].sort(key=lambda x: x[0])
# NUL byte in a noise line of payments.log.1
raw = [l for _, l in pl]
raw[2] = raw[2][:20] + "\x00" + raw[2][20:]
for name, rows in files.items():
    lines = raw if name == "payments.log.1" else [l for _, l in rows]
    data = ("\n".join(lines) + "\n").encode("latin-1")
    if name.endswith(".gz"):
        with gzip.GzipFile(f"{sb}/logs/{name}", "wb", mtime=0) as f: f.write(data)
    else:
        open(f"{sb}/logs/{name}", "wb").write(data)
hits.sort(key=lambda x: x[0])
open(f"{sb}/.lm/trail.txt", "w").write("\n".join(l for _, l in hits) + "\n")
PY
exit 0
