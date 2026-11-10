#!/bin/bash
# Every path in perms.acl matches a restore of that dump (mode and ACL
# entries); every other path follows POLICY.md and has no named ACL entries;
# nothing is world-writable.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
[ -s perms.acl ] && [ -d app ] || { echo "❌ perms.acl or app/ is missing; type 'reset'"; exit 1; }
TMP=$(mktemp -d); trap 'chmod -R u+rwx "$TMP" 2>/dev/null; rm -rf "$TMP"' EXIT
u=$(find app ! -readable 2>/dev/null | head -1)
if [ -n "$u" ]; then echo "❌ $u cannot be read even by its owner, so the app cannot use it"; exit 1; fi
cp -a app "$TMP/app" || { echo "❌ cannot copy app/ for comparison"; exit 1; }
(cd "$TMP" && setfacl --restore="$SANDBOX/perms.acl" >/dev/null 2>&1)
getfacl -R -p app > "$TMP/real.txt" 2>/dev/null
(cd "$TMP" && getfacl -R -p app > expect.txt 2>/dev/null)
python3 - "$TMP/real.txt" "$TMP/expect.txt" perms.acl <<'PY'
import os, re, sys
def unesc(s): return re.sub(r"\\([0-7]{3})", lambda m: chr(int(m.group(1), 8)), s)
def blocks(path):
    out = {}; cur = None
    for line in open(path, errors="replace").read().split("\n"):
        if line.startswith("# file: "):
            cur = unesc(line[8:]); out[cur] = []
        elif cur is not None and line.strip() and not line.startswith(("# owner", "# group")):
            out[cur].append(line.strip())
    return out
real, exp = blocks(sys.argv[1]), blocks(sys.argv[2])
dump = set(blocks(sys.argv[3]))
for p in sorted(dump):
    if p not in real:
        print("❌ %s from perms.acl no longer exists" % p); sys.exit(1)
for p in sorted(dump):
    if real[p] != exp[p]:
        r, e = set(real[p]), set(exp[p])
        what = "a named ACL entry" if any(x.startswith(("user:", "group:")) and x.split(":")[1] for x in r ^ e) else "its mode"
        print("❌ %s differs from the dump in %s" % (p, what)); sys.exit(1)
for p in sorted(real):
    if p in dump: continue
    st = os.lstat(p); mode = st.st_mode & 0o7777
    isdir = os.path.isdir(p)
    parts = p.split("/")
    if isdir: want = 0o2750
    elif "secrets" in parts[:-1]: want = 0o600
    elif "bin" in parts[:-1]: want = 0o750
    else: want = 0o640
    if mode != want:
        print("❌ %s (not in the dump) is %o, POLICY.md says %o" % (p, mode, want)); sys.exit(1)
    if any(x.startswith(("user:", "group:")) and x.split(":")[1] for x in real[p]):
        print("❌ %s (not in the dump) has a named ACL entry the policy does not allow" % p); sys.exit(1)
bad = [p for p in real if os.lstat(p).st_mode & 0o002]
if bad:
    print("❌ %s is still world-writable" % bad[0]); sys.exit(1)
PY
[ $? -eq 0 ] || exit 1
echo "✅ every path matches the dump or the policy, ACL entries restored, nothing world-writable"
