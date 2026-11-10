#!/bin/bash
# Directories must be exactly 3770, regular files 660 (770 if any x bit at
# setup). Symlinks stay links and their outside target keeps its mode. The set
# of entries is unchanged, and everything has the top directory's group.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
T=srv/projects/apollo
if [ ! -s .lm-state/entries ] || [ ! -d "$T" ]; then
  echo "❌ the level's data is gone; type 'reset'"
  exit 1
fi
python3 - <<'PY'
import os, stat, sys
T = "srv/projects/apollo"
entries = open(".lm-state/entries").read().split("\n")[:-1]
execs = set(open(".lm-state/exec").read().split("\n")) - {""}
now = []
def bad(e):
    print("❌ the directory %s can no longer be entered or listed: a directory needs its execute bit" % e.filename)
    sys.exit(1)
for root, ds, fs in os.walk(T, onerror=bad):
    for n in ds + fs:
        now.append("./" + os.path.relpath(os.path.join(root, n), T))
now.append(".")
now = sorted(now)
if now != entries:
    miss = [e for e in entries if e not in now]
    extra = [e for e in now if e not in entries]
    print("❌ the tree changed: %s" % (("%s is gone" % miss[0]) if miss else ("%s is new" % extra[0])))
    sys.exit(1)
vendor = "srv/shared/vendor-notes.txt"
link = os.path.join(T, "docs/vendor-notes.txt")
if not os.path.islink(link):
    print("❌ docs/vendor-notes.txt is not a symlink any more")
    sys.exit(1)
vm = stat.S_IMODE(os.stat(vendor).st_mode)
if vm != 0o644:
    print("❌ srv/shared/vendor-notes.txt, outside the project, now has mode %o: a symlink inside the tree let chmod change it" % vm)
    sys.exit(1)
topgid = os.lstat(T).st_gid
for rel in entries:
    p = T if rel == "." else os.path.join(T, rel[2:])
    st = os.lstat(p)
    m = stat.S_IMODE(st.st_mode)
    name = "the top directory" if rel == "." else rel[2:]
    dname = "the top directory" if rel == "." else "the directory " + rel[2:]
    if stat.S_ISLNK(st.st_mode):
        continue
    if st.st_gid != topgid:
        print("❌ %s belongs to another group than the project directory" % name)
        sys.exit(1)
    if stat.S_ISDIR(st.st_mode):
        if m == 0o3770:
            continue
        if m & 0o007:
            print("❌ outsiders still have access to %s (mode %04o)" % (dname, m))
        elif (m & 0o770) != 0o770:
            print("❌ the owner or team lacks full access to %s (mode %04o)" % (dname, m))
        elif not m & 0o2000:
            print("❌ files created in %s would not inherit the team's group (mode %04o)" % (dname, m))
        else:
            print("❌ in %s anyone with write access can still delete others' files (mode %04o)" % (dname, m))
        sys.exit(1)
    if stat.S_ISREG(st.st_mode):
        want = 0o770 if rel[2:] in execs else 0o660
        if m == want:
            continue
        if m & 0o007:
            print("❌ outsiders can still reach the file %s (mode %04o)" % (name, m))
        elif m & 0o6000:
            print("❌ the file %s has a set-id bit (mode %04o)" % (name, m))
        elif (m & 0o660) != 0o660:
            print("❌ the file %s is not readable and writable for both owner and team (mode %04o)" % (name, m))
        elif want == 0o660:
            print("❌ the file %s is executable (mode %04o) but was a plain data file" % (name, m))
        else:
            print("❌ the file %s was a program and should stay executable for owner and team (mode %04o)" % (name, m))
        sys.exit(1)
print("✅ the Apollo tree is a safe team directory: %d directories 3770, %d files 660/770, the vendor link untouched" % (
    sum(1 for e in entries if os.path.isdir(os.path.join(T, e)) and not os.path.islink(os.path.join(T, e))),
    sum(1 for e in entries if os.path.isfile(os.path.join(T, e)) and not os.path.islink(os.path.join(T, e)))))
PY
