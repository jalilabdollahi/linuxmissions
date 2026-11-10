#!/bin/bash
# app.log (~11 000 lines). Three noisy templates (2 400 - 3 400 lines each), a fourth
# chatty template well below them, and ERROR/WARN lines that resemble the noisy ones:
# an ERROR with the same URL as the noisy DEBUG line, an ERROR "cache miss", a WARN
# healthcheck failure. A copy of the log and the set of line numbers that must go are
# kept in .lm-state (the player may edit app.log; the validator uses the copy).
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

python3 - <<'LMEND'
import random, time
r = random.randint
def hexid(): return "%08x" % random.getrandbits(32)
def ip(): return f"10.{r(0,3)}.{r(0,255)}.{r(1,254)}"
noisy = [
    (r(2900, 3400), lambda: f"INFO cache hit key=user:{r(1000,99999)} ttl={r(30,900)}s node={ip()}"),
    (r(2500, 3000), lambda: f"DEBUG http GET /v1/errors/report?session={hexid()} status=200 took={r(1,90)}ms"),
    (r(2400, 2800), lambda: f"INFO healthcheck probe from {ip()} ok in {r(1,30)}ms"),
]
quiet = [
    (r(600, 800), lambda: f"INFO order {r(10000,99999)} created by user {r(1000,99999)} amount={r(1,500)}.{r(0,99):02d}"),
    (r(450, 550), lambda: f"INFO cache evict key=user:{r(1000,99999)} reason=ttl"),
    (r(380, 460), lambda: f"DEBUG http GET /v1/items?id={r(1,9999)} status=200 took={r(1,90)}ms"),
    (r(280, 340), lambda: f"INFO user {r(1000,99999)} logged in from {ip()}"),
    (r(100, 140), lambda: f"WARN slow query {r(500,4000)}ms: SELECT * FROM orders WHERE customer={r(1,9999)}"),
    (r(70, 100), lambda: f"WARN healthcheck probe from {ip()} failed: timeout after {r(1,5)}000ms"),
    (r(50, 70), lambda: f"ERROR cache miss key=user:{r(1000,99999)} backend timeout after {r(1,9)}s"),
    (r(40, 60), lambda: f"ERROR http GET /v1/errors/report?session={hexid()} status=502 took={r(1000,9000)}ms"),
    (r(35, 55), lambda: f"ERROR payment {r(10000,99999)} declined: card error code={r(100,999)}"),
    (r(25, 40), lambda: f"ERROR worker {r(1,9)} crashed with exit code {r(1,255)}, restarting"),
]
day = 1762000000 + r(0, 5 * 86400)
day -= day % 86400
rows = []
for kind, group in (("N", noisy), ("Q", quiet)):
    for n, f in group:
        for _ in range(n):
            rows.append((day + r(0, 86399), random.random(), kind, f()))
rows.sort()
with open("app.log", "w") as f, open(".lm-state/noisy.lines", "w") as g:
    for i, (t, _, kind, msg) in enumerate(rows, 1):
        f.write(time.strftime("%Y-%m-%d %H:%M:%S", time.gmtime(t)) + " " + msg + "\n")
        if kind == "N":
            g.write(f"{i}\n")
LMEND
[ -s app.log ] || { echo "data generation failed" >&2; exit 1; }
cp app.log .lm-state/app.log.orig
awk 'NR==FNR {d[$1]; next} !(FNR in d) {print FNR}' .lm-state/noisy.lines app.log | sort > .lm-state/keep.lines
sort .lm-state/noisy.lines > .lm-state/noisy.sorted
