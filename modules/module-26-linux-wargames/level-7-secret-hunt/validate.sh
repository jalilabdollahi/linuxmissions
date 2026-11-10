#!/bin/bash
# leaks.txt exact; no plain-text/base64/continued copy of the key left in
# regular files; the rest of each edited file intact; archives and all other
# files byte-identical.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
[ -s .lm-state/truth.json ] || { echo "❌ the level's data is gone; type 'reset'"; exit 1; }
if [ ! -f leaks.txt ]; then echo "❌ leaks.txt does not exist"; exit 1; fi
python3 - <<'PY'
import json, os, sys, hashlib
t = json.load(open(".lm-state/truth.json"))
key, h1, h2, b64 = t["key"], t["half1"], t["half2"], t["b64"]
got = set()
for l in open("leaks.txt", errors="replace"):
    l = l.replace("\r", "").strip()
    if l.startswith("./"): l = l[2:]
    if l: got.add(l)
exp = set(t["leaks"])
if got != exp:
    miss = sorted(exp - got); extra = sorted(got - exp)
    if extra: print("❌ leaks.txt lists %s, which does not hold our key (look closely at the key: similar is not the same)" % extra[0]); sys.exit(1)
    print("❌ leaks.txt is missing %d location(s); the key also hides in archives, in encoded form and across line breaks" % len(miss)); sys.exit(1)
files = []
for r, _, fs in os.walk("site"):
    for f in fs: files.append(os.path.join(r, f))
for p in files:
    if p.endswith((".gz", ".tgz")): continue
    d = open(p, "rb").read().decode("utf-8", "replace")
    for what, s in (("the key", key), ("the first half of the key", h1), ("the rest of the key", h2), ("the base64 form of the key", b64)):
        if s in d:
            print("❌ %s is still in %s" % (what, p)); sys.exit(1)
expsum = [l.rstrip("\n").split("  ", 1) for l in open(".lm-state/all.sum")]
leakfiles = set(t["leakfiles"])
for h, p in expsum:
    if not os.path.exists(p):
        print("❌ %s was deleted; redact in place, do not remove files" % p); sys.exit(1)
    if p in leakfiles: continue
    if hashlib.sha256(open(p, "rb").read()).hexdigest() != h:
        print("❌ %s changed, but it should not have been touched (archives are listed, never modified; look-alike keys stay)" % p); sys.exit(1)
for p in leakfiles:
    orig = open(os.path.join(".lm-state/orig", p), errors="replace").read().split("\n")
    now = open(p, errors="replace").read()
    if "REDACTED" not in now and "UkVEQUNURUQ" not in now:
        print("❌ %s no longer holds the key but has no REDACTED marker where it was" % p); sys.exit(1)
    bad = (key, h1, h2, b64)
    keep = [l for l in orig if not any(s in l for s in bad)]
    nl = [l for l in now.split("\n") if "REDACTED" not in l and "UkVEQUNURUQ" not in l]
    ol = [l for l in keep if True]
    # lines that were not part of the leak must still be there, in order
    it = iter(nl)
    if not all(any(x == y for y in it) for x in ol):
        print("❌ %s lost lines that had nothing to do with the leak" % p); sys.exit(1)
PY
[ $? -eq 0 ] || exit 1
echo "✅ every copy of the key is listed and redacted, archives and everything else untouched"
