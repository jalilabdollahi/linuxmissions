#!/bin/bash
# Exact set of files under var/ and exact content of every .gz; the batch job
# is alive and still holds the same two (undeleted, unrenamed) files.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
[ -s .lm-state/truth.json ] && [ -s .lm-state/pid ] || { echo "❌ the level's data is gone; type 'reset'"; exit 1; }
pid=$(cat .lm-state/pid)
if ! kill -0 "$pid" 2>/dev/null || ! tr '\0' ' ' < /proc/$pid/cmdline 2>/dev/null | grep -q "$SANDBOX/bin/batch.py"; then
  echo "❌ the batch job is not running any more; it must not be disturbed"; exit 1
fi
python3 - "$pid" <<'PY'
import gzip, hashlib, json, os, sys
pid = sys.argv[1]
t = json.load(open(".lm-state/truth.json"))
exp = t["expected"]
for p, ino in t["held"].items():
    if not os.path.exists(p) or os.stat(p).st_ino != ino:
        print("❌ %s is held open by the batch job and must stay exactly as it was (not deleted, not compressed)" % p); sys.exit(1)
    if os.path.exists(p + ".gz"):
        print("❌ %s was compressed although the batch job holds it open" % p); sys.exit(1)
fds = [os.readlink("/proc/%s/fd/%s" % (pid, f)) for f in os.listdir("/proc/%s/fd" % pid)]
for p in t["held"]:
    if os.path.abspath(p) not in fds:
        print("❌ the batch job no longer has %s open" % p); sys.exit(1)
have = set()
for r, d, fs in os.walk("var"):
    for f in fs: have.add(os.path.join(r, f))
extra = sorted(have - set(exp)); missing = sorted(set(exp) - have)
if missing:
    m = missing[0]
    if m.endswith(".gz") and m[:-3] in have: print("❌ %r is 2-7 days old: it should be compressed, not left as it is" % m[:-3])
    else: print("❌ %r should still exist (or be there compressed): look at what the policy keeps" % m)
    sys.exit(1)
if extra:
    e = extra[0]
    print("❌ %r should be gone: %s" % (e, "older than 7 days" if e.endswith(".log") else "an expired core dump" if "/core." in e else "not in the policy's keep list"))
    sys.exit(1)
for p, sha in exp.items():
    data = gzip.open(p, "rb").read() if p.endswith(".gz") else open(p, "rb").read()
    if hashlib.sha256(data).hexdigest() != sha:
        print("❌ the content of %r changed" % p); sys.exit(1)
PY
[ $? -eq 0 ] || exit 1
echo "✅ var/ matches RETENTION.md exactly and the batch job's files are untouched"
