#!/bin/bash
# Wargame 29: five services, five time formats, five names for the request ID.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
rm -rf logs TICKET.txt TIMES.md rootcause.txt timeline.tsv .lm
mkdir -p logs .lm
cat > TIMES.md <<'MD'
gateway.log    2026-11-09T14:31:07.482Z gateway LEVEL request_id=...        UTC
checkout.log   2026-11-09 18:01:07,533 +0330 checkout [LEVEL] X-Request-ID=...   local time, UTC+03:30
payments.log   JSON lines: {"ts": epoch milliseconds (UTC), "level", "trace": request id, "msg"}
inventory.log  09/Nov/2026:14:31:07.482 +0000 LEVEL [req=...] message          UTC; ERROR events are
               followed by a Java stack trace on lines that have no time stamp
notifier.log   2026-11-09T15:31:07+01:00 notifier LEVEL rid=...                 UTC+01:00, whole seconds
MD
python3 - <<'PY'
import json, os, random
from datetime import datetime, timedelta, timezone
rnd = random.Random(os.urandom(8))
UTC = timezone.utc
base = datetime(2026, 11, 9, 14, 0, 0, tzinfo=UTC)
ev = {k: [] for k in ("gateway", "checkout", "payments", "inventory", "notifier")}   # (utc datetime, text)
events = []   # (utc, service, level, rid)
def rid(): return "req-%012x" % rnd.getrandbits(48)
def g(t, lvl, r, msg): ev["gateway"].append((t, "%s gateway %s request_id=%s %s" % (t.strftime("%Y-%m-%dT%H:%M:%S.") + "%03dZ" % (t.microsecond // 1000), lvl, r, msg)))
def c(t, lvl, r, msg):
    l = t.astimezone(timezone(timedelta(hours=3, minutes=30)))
    ev["checkout"].append((t, "%s,%03d +0330 checkout [%s] X-Request-ID=%s %s" % (l.strftime("%Y-%m-%d %H:%M:%S"), l.microsecond // 1000, lvl, r, msg)))
def p(t, lvl, r, msg): ev["payments"].append((t, json.dumps({"ts": int(t.timestamp() * 1000) + 0, "svc": "payments", "level": lvl, "trace": r, "msg": msg})))
def inv(t, lvl, r, msg, trace=None):
    ev["inventory"].append((t, "%s.%03d +0000 %s [req=%s] %s" % (t.strftime("%d/Nov/2026:%H:%M:%S"), t.microsecond // 1000, lvl, r, msg) + ("\n" + trace if trace else "")))
def n(t, lvl, r, msg):
    l = t.astimezone(timezone(timedelta(hours=1)))
    ev["notifier"].append((t, "%s notifier %s rid=%s %s" % (l.strftime("%Y-%m-%dT%H:%M:%S+01:00"), lvl, r, msg)))
def rec(t, s, l, r): events.append((t, s, l, r))
N = 700
times = sorted(base + timedelta(milliseconds=rnd.randint(0, 3590000)) for _ in range(N))
bad_idx = set(rnd.sample(range(40, N), 14))
stack = "java.sql.SQLTransientConnectionException: inventory-pool - Connection is not available, request timed out after 2000ms.\n" + "\n".join(
    "\tat com.shop.inventory.%s.%s(%s.java:%d)" % (rnd.choice(["repo", "service", "pool", "http"]), rnd.choice(["reserve", "acquire", "lookup", "handle", "run"]), rnd.choice(["StockRepo", "PoolManager", "ReserveHandler", "Worker"]), rnd.randint(20, 400)) for _ in range(38)) + "\nCaused by: java.net.SocketTimeoutException: connect timed out"
decoys_done = 0
bad = []
for i, t in enumerate(times):
    r = rid()
    ms = lambda a: t + timedelta(milliseconds=a)
    g(t, "INFO", r, "accepted method=POST path=/checkout")
    c(ms(3), "INFO", r, "checkout started")
    inv(ms(9), "INFO", r, "reserve start sku=SKU-%d" % rnd.randint(1000, 9999))
    if i in bad_idx:
        e = ms(14 + rnd.randint(0, 5))
        inv(e, "ERROR", r, "connection pool exhausted (active=40 waiting=%d)" % rnd.randint(20, 90), stack)
        c(e + timedelta(milliseconds=2012), "ERROR", r, "inventory call failed: timeout after 2000ms")
        g(e + timedelta(milliseconds=2105), "ERROR", r, "completed status=502 dur_ms=2105")
        n(e + timedelta(seconds=3), "WARN", r, "alert queued for ops, no customer mail")
        bad.append((t, r, e))
        for tt, s, l in ((t, "gateway", "INFO"), (ms(3), "checkout", "INFO"), (ms(9), "inventory", "INFO"), (e, "inventory", "ERROR"), (e + timedelta(milliseconds=2012), "checkout", "ERROR"), (e + timedelta(milliseconds=2105), "gateway", "ERROR"), (e + timedelta(seconds=3), "notifier", "WARN")):
            rec(tt, s, l, r)
    else:
        inv(ms(17), "INFO", r, "reserve ok")
        retry = (decoys_done < 2 and 60 < i < 300 and rnd.random() < .08)
        if retry:
            decoys_done += 1
            p(ms(40), "ERROR", r, "card gateway timeout, retrying")
            p(ms(1100), "INFO", r, "charge ok after retry")
        else:
            p(ms(44), "INFO", r, "charge ok amount=%d.%02d" % (rnd.randint(5, 300), rnd.randint(0, 99)))
        c(ms(90), "INFO", r, "checkout completed")
        g(ms(96), "INFO", r, "completed status=200 dur_ms=%d" % rnd.randint(80, 140))
        if decoys_done == 1 and retry or rnd.random() < .004:
            n(ms(2000), "ERROR", r, "smtp 451 temporary failure, will retry")
        else:
            n(ms(1500), "INFO", r, "receipt mail queued")
for k in range(80):    # health noise on the gateway
    t = base + timedelta(milliseconds=rnd.randint(0, 3599000)); g(t, "INFO", "-", "GET /health status=200")
first = min(bad, key=lambda x: x[2])
# the ticket asks about a later failing request
tick = sorted(bad, key=lambda x: x[0])[rnd.randint(4, 12)]
open("TICKET.txt", "w").write("Ticket SUP-5120\nThe gateway shows request_id=%s failing with 502 around %s UTC.\nWe need to know what started it, and the full path of this request.\n" % (tick[1], tick[0].strftime("%H:%M")))
for sv, rows in ev.items():
    rows.sort(key=lambda x: x[0])
    lines = [l for _, l in rows]
    if sv == "payments":
        lines = [l for _, l in rows]
    open("logs/%s.log" % sv, "w").write("\n".join(lines) + "\n")
# expected
errline = [l for t, l in ev["inventory"] if "[req=%s]" % first[1] in l and " ERROR " in l][0].split("\n")[0]
open(".lm/rootcause.txt", "w").write("inventory\n" + errline + "\n")
rows = sorted((t, s, l) for t, s, l, r in events if r == tick[1])
def fmt(t, s):
    if s == "notifier": t = t.replace(microsecond=0)
    return t.astimezone(UTC).strftime("%Y-%m-%dT%H:%M:%S.") + "%03dZ" % (t.microsecond // 1000)
open(".lm/timeline.tsv", "w").write("".join("%s\t%s\t%s\n" % (fmt(t, s), s, l) for t, s, l in rows))
PY
exit 0
