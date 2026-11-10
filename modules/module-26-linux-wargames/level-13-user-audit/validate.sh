#!/bin/bash
# passwd/group exact, shadow locks exact, every authorized_keys exact (no
# departed body left, nothing else lost), audit.txt exact.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
[ -s .lm-state/truth.json ] || { echo "❌ the level's data is gone; type 'reset'"; exit 1; }
python3 - <<'PY'
import json, os, sys
t = json.load(open(".lm-state/truth.json"))
sr = "sysroot/"
rd = lambda p: [l.rstrip("\r\n") for l in open(sr + p, errors="replace")] if os.path.exists(sr + p) else None
bd = t["backdoor"]
pw = rd("etc/passwd") or []
if any(l.split(":")[0] == bd for l in pw) or any(l.split(":")[2] == "0" and l.split(":")[0] != "root" for l in pw if l.count(":") >= 6):
    print("❌ an account with UID 0 other than root is still in etc/passwd"); sys.exit(1)
if pw != t["passwd"]:
    gone = [l for l in t["passwd"] if l not in pw]
    print("❌ etc/passwd differs from what it should be: %s" % ("a line that should stay is missing or changed (%s)" % gone[0].split(":")[0] if gone else "an unexpected line was added or changed")); sys.exit(1)
sh = rd("etc/shadow") or []
orig = {l.split(":")[0]: l.split(":") for l in t["shadow_orig"]}
if any(l.split(":")[0] == bd for l in sh):
    print("❌ the backdoor account is still in etc/shadow"); sys.exit(1)
seen = {}
for l in sh:
    f = l.split(":"); seen[f[0]] = f
for n, o in orig.items():
    if n == bd: continue
    if n not in seen:
        print("❌ the shadow entry of %s disappeared" % n); sys.exit(1)
    f = seen[n]
    if n in t["gone"]:
        if f[1] != "!" + o[1]:
            print("❌ %s is not locked in etc/shadow (a locked password starts with !, and the hash behind it must stay)" % n); sys.exit(1)
    elif f[1] != o[1]:
        print("❌ the password field of %s changed, but only the departed accounts may be locked" % n); sys.exit(1)
if len(seen) != len(orig) - 1:
    print("❌ etc/shadow has an unexpected number of entries"); sys.exit(1)
if rd("etc/group") != t["group"]:
    print("❌ etc/group is not as expected: the removed account must not remain a member of any group, and nothing else should change"); sys.exit(1)
for p, exp in t["ak"].items():
    got = rd(p)
    if got is None:
        print("❌ %s is gone" % p); sys.exit(1)
    left = [b for b in t["bodies"] if any(b in l for l in got)]
    if left:
        print("❌ a departed person's key is still in %s" % p); sys.exit(1)
    if [l for l in got if l.strip()] != exp:
        print("❌ %s lost or changed lines that are not the departed people's keys" % p); sys.exit(1)
if not os.path.isfile("audit.txt"):
    print("❌ audit.txt does not exist"); sys.exit(1)
got = sorted(set(l.strip() for l in open("audit.txt", errors="replace") if l.strip()))
if got != t["audit"]:
    ex = [l for l in got if l not in t["audit"]]; mi = [l for l in t["audit"] if l not in got]
    if ex: print("❌ audit.txt has a finding that is wrong or badly formatted: %s" % ex[0])
    else: print("❌ audit.txt is missing %d finding(s) (locked accounts, removed key lines, the UID-0 account)" % len(mi))
    sys.exit(1)
PY
[ $? -eq 0 ] || exit 1
echo "✅ accounts locked, backdoor gone, every departed key removed everywhere, audit exact"
