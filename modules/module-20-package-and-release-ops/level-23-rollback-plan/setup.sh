#!/bin/bash
# Rollback Plan: releases/<v>/ directories, a `current` symlink to the broken 1.6.0, a deploy.log with
# several ok / failed / rolled-back deploys (the release just before 1.6.0 was itself rolled back,
# sometimes two were), and a small app server (level-local helper app.py) that loads `current` at
# start and on SIGHUP. 1.6.0 needs database schema 7, the database has 6.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
HERE="$(cd "$(dirname "$0")" && pwd)"
mkdir -p bin data run var .lm releases
cp "$HERE/app.py" bin/app; chmod 755 bin/app
PORT=""
for _ in $(seq 1 30); do
  p=$((20000 + RANDOM % 20000))
  python3 - "$p" <<'PY' && { PORT=$p; break; }
import socket, sys
s = socket.socket(); s.bind(("127.0.0.1", int(sys.argv[1]))); s.close()
PY
done
[ -n "$PORT" ] || { echo "no free port"; exit 1; }
echo "$PORT" > app.port
echo 6 > data/db.schema
python3 - <<'PY' || exit 1
import datetime, hashlib, os, random
r = random.Random()
pool = ["1.2.0", "1.2.1", "1.3.0", "1.3.1", "1.4.0", "1.4.1", "1.5.0", "1.5.1"]
older = sorted(r.sample(pool, 5), key=lambda s: tuple(map(int, s.split("."))))
rolled = {older[4]}
if r.random() < .5: rolled.add(older[3])
failed = set()
cand = [v for v in older[:3]]
if r.random() < .6:
    failed.add(r.choice([c for c in cand[1:]]))
now = datetime.datetime.utcnow()
t = now - datetime.timedelta(days=40)
lines = []
good = None
for v in older:
    t += datetime.timedelta(days=r.randint(2, 6), minutes=r.randint(0, 600))
    st = "failed" if v in failed else "ok"
    lines.append((t, f"DEPLOY {v} {st}"))
    if v in rolled:
        reason = r.choice(["checkout bug reported by support", "latency regression", "wrong totals in invoices", "memory growth"])
        lines.append((t + datetime.timedelta(minutes=r.randint(15, 90)), f"ROLLBACK {v} -> @@ {reason}"))
# resolve rollback targets: the last good release before the rolled-back one
out, goodsofar = [], []
for ts, text in lines:
    if text.startswith("DEPLOY"):
        _, v, st = text.split()
        if st == "ok" and v not in rolled: goodsofar.append(v)
    if "@@" in text:
        text = text.replace("@@", goodsofar[-1])
    out.append((ts, text))
good = [v for v in older if v not in rolled and v not in failed][-1]
last_t = now - datetime.timedelta(minutes=10)
out.append((last_t, "DEPLOY 1.6.0 pending"))
with open("deploy.log", "w") as f:
    for ts, text in out:
        f.write(ts.strftime("%Y-%m-%dT%H:%M:%SZ ") + text + "\n")
for v in older + ["1.6.0"]:
    d = f"releases/{v}"
    os.makedirs(d + "/bin", exist_ok=True)
    open(d + "/VERSION", "w").write(v + "\n")
    open(d + "/app.conf", "w").write(f"# app {v}\nschema = {7 if v == '1.6.0' else 6}\nworkers = {r.randint(2, 8)}\n")
    open(d + "/bin/serve", "w").write(f"#!/bin/sh\n# serve {v}\n")
open("releases/1.6.0/crash.log", "w").write("startup check failed: database schema is 6, release needs 7\n")
os.symlink("releases/1.6.0", "current")
open(".lm/good", "w").write(good + "\n")
open(".lm/log.orig", "w").write(open("deploy.log").read())
files = []
for dp, dn, fn in os.walk("releases/1.6.0"):
    for x in fn:
        p = os.path.join(dp, x); files.append(f"{hashlib.md5(open(p,'rb').read()).hexdigest()}  {p}")
open(".lm/r160.md5", "w").write("\n".join(sorted(files)) + "\n")
open(".lm/rolledback", "w").write("\n".join(sorted(rolled | failed)) + "\n")
PY
nohup python3 "$SANDBOX/bin/app" daemon --root "$SANDBOX" >"$SANDBOX/var/app.log" 2>&1 &
for _ in $(seq 1 50); do
  curl -s -m 1 "http://127.0.0.1:$PORT/health" >/dev/null 2>&1 && break
  sleep 0.1
done
