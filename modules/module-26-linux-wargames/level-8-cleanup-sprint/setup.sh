#!/bin/bash
# var/ is full. RETENTION.md: *.log older than 7 days deleted, 2-7 days old
# gzipped, core dumps older than 30 days deleted, .keep kept, files held open
# by the running batch process left alone. Names contain spaces/newlines and
# lie about their dates. Ages avoid the find -mtime truncation boundaries.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p bin .lm-state var/log/batch var/log/web var/log/old var/crash var/cache
cat > bin/batch.py <<'PY'
#!/usr/bin/env python3
# Nightly batch job: keeps its ledger files open (read/append handles, idle
# until 09:00), so deleting or compressing them behind its back is a bug.
import os, sys, time
conf = os.environ["BATCH_VAR"]
handles = [open(os.path.join(conf, p), "a") for p in sys.argv[1:]]
open(os.path.join(conf, "..", ".lm-state", "pid"), "w").write(str(os.getpid()))
t0 = time.time()
while time.time() - t0 < 3 * 3600:
    time.sleep(1)
PY
python3 - <<'PY'
import gzip, hashlib, json, os, random, time
R = random.Random()
now = time.time()
DAY = 86400
def mk(path, age_days, size=None, text=None):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    data = (text if text is not None else "".join("line %d %s\n" % (i, R.getrandbits(40)) for i in range(R.randint(30, 200)))).encode()
    open(path, "wb").write(data)
    t = now - age_days * DAY
    os.utime(path, (t, t))
    return hashlib.sha256(data).hexdigest()
old = lambda: R.uniform(8.3, 40)       # delete
mid = lambda: R.uniform(2.3, 6.7)      # gzip
new = lambda: R.uniform(0.1, 1.6)      # keep
items = []   # (path, age, kind)
def add(path, age, kind): items.append((path, age, kind))
names_old = ["web/access-2026-11-08.log", "web/access-2026-11-09.log", "web/error report.log", "batch/run 2026-10-02.log", "old/archive-a.log", "old/archive-b.log"]
for n in names_old: add("var/log/" + n, old(), "log")
add("var/log/web/odd\nname-old.log", old(), "log")
names_mid = ["web/access-2026-10-01.log", "web/slow queries.log", "batch/run 2026-11-05.log", "old/notes.log"]
for n in names_mid: add("var/log/" + n, mid(), "log")
add("var/log/web/two\nlines-mid.log", mid(), "log")
names_new = ["web/access-2020-01-01.log", "web/access-2026-11-10.log", "batch/run 2026-11-10.log", "web/live feed.log"]
for n in names_new: add("var/log/" + n, new(), "log")
for i in range(R.randint(3, 4)): add("var/crash/core.%d" % R.randint(1000, 99999), R.uniform(31.2, 90), "core")
for i in range(R.randint(2, 3)): add("var/crash/core.%d" % R.randint(100000, 199999), R.uniform(1, 29), "core")
for d in ("var/log/old", "var/crash", "var/log/web"): add(d + "/.keep", R.uniform(60, 400), "keep")
for n in ("var/log/README", "var/cache/index.dat", "var/cache/old-session.dat"): add(n, R.uniform(10, 60), "other")
# held open by the batch job: one very old (would be deleted), one mid-age (would be gzipped)
heldA = "var/log/batch/ledger-2026-10-30.log"; heldB = "var/log/batch/ledger-current.log"
add(heldA, R.uniform(9.2, 12), "held"); add(heldB, R.uniform(3, 5), "held")
exp = {}; shas = {}; ino = {}
seen = set()
for p, age, kind in items:
    if p in seen: continue
    seen.add(p)
    sha = mk(p, age)
    shas[p] = sha
    if kind == "log":
        if age > 7: continue
        exp[p + ".gz" if age >= 2 else p] = sha
    elif kind == "core":
        if age > 30: continue
        exp[p] = sha
    else:
        exp[p] = sha
for p in (heldA, heldB): ino[p] = os.stat(p).st_ino
json.dump({"expected": exp, "held": ino, "gzipped": [p + ".gz" for p, a, k in items if k == "log" and 2 <= a <= 7]}, open(".lm-state/truth.json", "w"))
open("RETENTION.md", "w").write("""# Retention for var/ (the 09:00 batch needs the space)

- `*.log` files older than 7 days: delete.
- `*.log` files between 2 and 7 days old: compress with gzip (keep the data,
  the original goes away, the name gets `.gz`).
- younger logs: leave alone.
- core dumps (`var/crash/core.*`) older than 30 days: delete.
- `.keep` files stay, whatever their age; so does everything that is not a
  `*.log` or a core dump.
- Anything held open by the running batch job is left exactly as it is,
  even when its age says otherwise: the job still writes to it at 09:00.
- Age means modification time. Dates inside file names are often wrong.
  Some names contain spaces, and some contain a newline.
""")
PY
BATCH_VAR="$SANDBOX/var" setsid python3 "$SANDBOX/bin/batch.py" log/batch/ledger-2026-10-30.log log/batch/ledger-current.log >/dev/null 2>&1 < /dev/null &
for i in $(seq 50); do [ -s .lm-state/pid ] && break; sleep 0.1; done
sleep 0.3
