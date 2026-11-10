#!/bin/bash
SB="$1"; cd "$SB" || exit 1
if [ ! -d bravo/data ]; then echo "❌ bravo/data does not exist yet"; exit 1; fi
python3 - <<'PY'
import hashlib, json, os, re, sys
man = json.load(open(".lm/manifest.json")); E = man["entries"]
def fail(m): print("❌ " + m); sys.exit(1)
# alpha untouched
for rel, e in E.items():
    p = "alpha/data/" + rel
    if not os.path.lexists(p): fail("alpha/data was modified (%s is gone)" % rel)
    if e["type"] == "f" and hashlib.sha256(open(p, "rb").read()).hexdigest() != e["sha"]: fail("alpha/data was modified (%s changed)" % rel)
# the data really went through the relay
acc = 0
if os.path.exists("relay.log"):
    for l in open("relay.log"):
        m = re.search(r" OK bytes=(\d+)", l)
        if m: acc += int(m.group(1))
if acc < man["bytes"]: fail("only %d bytes went through the relay but the tree holds %d: bravo/data must be built from what arrived in bravo/inbox" % (acc, man["bytes"]))
got = set()
for r, ds, fs in os.walk("bravo/data"):
    for n in ds + fs: got.add(os.path.relpath(os.path.join(r, n), "bravo/data"))
miss = set(E) - got; extra = got - set(E)
if miss: fail("%d path(s) missing in bravo/data (for example %s)" % (len(miss), sorted(miss)[0]))
if extra: fail("%d unexpected path(s) in bravo/data (for example %s)" % (len(extra), sorted(extra)[0]))
bad = {"type": [], "content": [], "mode": [], "link": [], "mtime": []}
inos = {}
for rel, e in E.items():
    p = "bravo/data/" + rel; st = os.lstat(p)
    t = "l" if os.path.islink(p) else "d" if os.path.isdir(p) else "f"
    if t != e["type"]: bad["type"].append(rel); continue
    if t == "l":
        if os.readlink(p) != e["target"]: bad["link"].append(rel)
    elif t == "f":
        if st.st_size != e["size"] or hashlib.sha256(open(p, "rb").read()).hexdigest() != e["sha"]: bad["content"].append(rel)
        inos.setdefault(e["ino"], []).append((rel, st.st_ino, st.st_nlink))
    if t != "l" and (st.st_mode & 0o7777) != e["mode"]: bad["mode"].append(rel)
    if int(st.st_mtime) != e["mtime"]: bad["mtime"].append(rel)
for k, v in bad.items():
    if v:
        msg = {"type": "has the wrong kind of entry", "content": "has different content", "mode": "has different permissions", "link": "points somewhere else", "mtime": "has a different modification time"}[k]
        fail("%d path(s) in bravo/data %s (for example %s)" % (len(v), msg, v[0]))
for ino, items in inos.items():
    if len(items) > 1:
        if len({i[1] for i in items}) != 1: fail("the hard-linked pair %s is two separate files in bravo/data" % items[0][0])
print("✅ bravo/data matches alpha/data in content, modes, links and times, and it travelled through the relay")
PY
