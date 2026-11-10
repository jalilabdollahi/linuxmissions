#!/bin/bash
# sysroot/etc/app must equal the newest snapshot that passes ./app --check-config, in file
# set, content, mode, symlink targets and mtimes; nothing else under sysroot may change.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
command -v python3 >/dev/null || { echo "❌ validator needs python3"; exit 1; }
cksum bin/app 2>/dev/null | cmp -s - .lm-state/sums || { echo "❌ the app tool was changed; type 'reset' to get it back"; exit 1; }
find sysroot -path sysroot/etc/app -prune -o -type f -print | sort | xargs cksum 2>/dev/null | cmp -s - .lm-state/outside || {
  echo "❌ something outside sysroot/etc/app was changed or removed"; exit 1; }
[ -d sysroot/etc/app ] || { echo "❌ sysroot/etc/app does not exist"; exit 1; }
python3 - <<'PYEOF'
import hashlib, os, stat, sys
def fail(m): print("❌ " + m); sys.exit(1)
def tree(root):
    out = {}
    for dp, dn, fn in os.walk(root):
        for name in dn + fn:
            p = os.path.join(dp, name); rel = os.path.relpath(p, root); st = os.lstat(p)
            if stat.S_ISLNK(st.st_mode): out[rel] = ("link", os.readlink(p), None, None)
            elif stat.S_ISDIR(st.st_mode): out[rel] = ("dir", None, stat.S_IMODE(st.st_mode), None)
            else: out[rel] = ("file", hashlib.sha256(open(p, "rb").read()).hexdigest(), stat.S_IMODE(st.st_mode), int(st.st_mtime))
    st = os.lstat(root); out["."] = ("dir", None, stat.S_IMODE(st.st_mode), None)
    return out
good = open(".lm-state/good").read().strip()
live = tree("sysroot/etc/app")
snaps = sorted(d for d in os.listdir("snapshots") if d.startswith("daily."))
want = tree("snapshots/%s/etc/app" % good)
def same(a, b, mtime=True):
    if set(a) != set(b): return False
    for k in a:
        x, y = a[k], b[k]
        if x[:3] != y[:3]: return False
        if mtime and x[3] != y[3]: return False
    return True
if same(live, want): 
    print("✅ sysroot/etc/app is restored from snapshots/%s, the newest one that passes the checker, with modes, links and mtimes intact" % good); sys.exit(0)
for s in snaps:
    if s != good and same(live, tree("snapshots/%s/etc/app" % s), mtime=False):
        fail("sysroot/etc/app matches snapshots/%s, which does not pass ./app --check-config (or is not the newest one that does)" % s)
extra = sorted(set(live) - set(want)); missing = sorted(set(want) - set(live))
if extra: fail("sysroot/etc/app still has file(s) the snapshot does not have (e.g. %s): files added after the upgrade must go" % extra[0])
if missing: fail("sysroot/etc/app is missing file(s) of the snapshot (e.g. %s)" % missing[0])
for k in sorted(want):
    a, b = live[k], want[k]
    if a[0] != b[0]: fail("%s has the wrong type (file, dir or link) compared to the snapshot" % k)
    if a[0] == "link" and a[1] != b[1]: fail("symlink %s points somewhere else than in the snapshot" % k)
    if a[0] == "file" and a[1] != b[1]: fail("content of %s differs from the snapshot" % k)
    if a[0] != "link" and a[2] != b[2]: fail("mode of %s is %04o, the snapshot has %04o" % (k, a[2], b[2]))
for k in sorted(want):
    if want[k][0] == "file" and live[k][3] != want[k][3]: fail("content and modes match, but the modification time of %s was not preserved" % k)
fail("sysroot/etc/app differs from the snapshot")
PYEOF
