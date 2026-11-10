#!/bin/bash
# $1 = sandbox path
# Expected code and timing per endpoint come from the server's route table
# (.net/http.json). status.tsv: exact codes, times consistent with each
# route's delay; bad.txt: exactly the non-2xx or >1 s URLs. Each endpoint
# must also have been requested (access log).
SANDBOX="$1"
cd "$SANDBOX" || exit 1

python3 - <<'PY'
import json, os, re, sys, time
from urllib.parse import urlsplit

def fail(msg):
    print("❌ " + msg)
    sys.exit(1)

routes = {r["path"]: r for r in json.load(open(".net/http.json"))["routes"]}
urls = [l.strip() for l in open("endpoints.txt") if l.strip() and not l.lstrip().startswith("#")]

def expect(url):
    r = routes[urlsplit(url).path]
    if r.get("hang"):
        return "000", None
    return str(r.get("status", 200)), r.get("delay", 0)

# The server logs a request when it ends; an abandoned hung request is
# noticed within ~0.2 s, so give the log a moment to catch up.
for attempt in range(12):
    log = open(".net/access.log").read() if os.path.exists(".net/access.log") else ""
    unseen = [u for u in urls if f" {urlsplit(u).path}" not in log]
    if not unseen:
        break
    time.sleep(0.2)
if unseen:
    fail(f"{urlsplit(unseen[0]).path} was never requested from the server; check every URL with curl")

try:
    raw = open("status.tsv", encoding="utf-8", errors="replace").read().replace("\r", "")
except FileNotFoundError:
    fail("status.tsv does not exist yet")
rows = {}
for line in raw.splitlines():
    if not line.strip():
        continue
    f = line.split()
    if len(f) != 3:
        fail(f"this status.tsv line doesn't have 3 fields (URL, code, time): {line[:80]}")
    if f[0] not in urls:
        fail(f"status.tsv: {f[0][:80]} is not a URL from endpoints.txt (copy it exactly, query string included)")
    if f[0] in rows:
        fail(f"status.tsv lists {f[0]} twice")
    rows[f[0]] = f[1:]
missing = [u for u in urls if u not in rows]
if missing:
    fail(f"status.tsv has {len(rows)} of the {len(urls)} URLs; {missing[0]} is missing")

bad = set()
for u in urls:
    code, delay = expect(u)
    gcode, gtime = rows[u]
    try:
        t = float(gtime)
    except ValueError:
        fail(f"status.tsv: the time for {u} is not a number of seconds ({gtime})")
    if gcode != code:
        if code == "000":
            fail(f"{u}: no response ever comes from this one; give curl a time limit and report its code (000)")
        if code.startswith("3") and gcode.startswith("2"):
            fail(f"{u}: {gcode} is the code after following a redirect; the ticket wants the code this URL itself answers")
        fail(f"{u}: the code in status.tsv ({gcode}) is not what the server answers")
    if code == "000":
        if t < 0.9:
            fail(f"{u}: a time of {gtime} s for a request that never got an answer? Write curl's time_total")
    elif t < delay - 0.05 or t > max(delay, 0.5) + 1.5:
        fail(f"{u}: {gtime} s doesn't match how long this endpoint takes; use curl's time_total")
    if not code.startswith("2") or delay > 1:
        bad.add(u)

try:
    got = [l.strip() for l in open("bad.txt", encoding="utf-8", errors="replace").read().replace("\r", "").splitlines() if l.strip()]
except FileNotFoundError:
    fail("status.tsv is right; now write bad.txt")
if len(got) != len(set(got)):
    fail("bad.txt lists a URL twice")
extra = [g for g in got if g not in bad]
if extra:
    fail(f"bad.txt: {extra[0]} is fine (2xx within 1 s)" if extra[0] in urls else f"bad.txt: {extra[0][:80]} is not a URL from endpoints.txt")
miss = bad - set(got)
if miss:
    u = sorted(miss)[0]
    what = {"000": "no answer", "3": "a redirect"}.get(expect(u)[0][:3] if expect(u)[0] == "000" else expect(u)[0][:1], "")
    fail(f"bad.txt misses {len(miss)} URL(s), e.g. one that is {what or 'not 2xx or slower than 1 s'}")
print(f"✅ {len(urls)} endpoints checked, {len(bad)} need attention")
PY
