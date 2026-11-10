#!/bin/bash
# matrix.csv must equal the model: reach the file (x on every directory above),
# then the first matching class decides: owner, else group (primary or
# supplementary), else other.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
if [ ! -s .lm-state/inputs ] || ! cksum etc/passwd etc/group stat.txt paths.txt 2>/dev/null | cmp -s - .lm-state/inputs; then
  echo "❌ one of the evidence files was changed; type 'reset' to get it back"
  exit 1
fi
if [ ! -f matrix.csv ]; then
  echo "❌ matrix.csv does not exist yet"
  exit 1
fi
python3 - <<'PY'
import sys
users = ["kim", "tomas", "priya", "wen", "alex"]
pw = {}
for l in open("etc/passwd"):
    f = l.rstrip("\n").split(":")
    pw[f[0]] = f[3]
gname, members = {}, {}
for l in open("etc/group"):
    n, _, gid, m = l.rstrip("\n").split(":")
    gname[gid] = n
    members[n] = [x for x in m.split(",") if x]
st = {}
for l in open("stat.txt"):
    mode, o, g, p = l.split()
    st[p] = (mode, o, g)
files = open("paths.txt").read().split()

def groups(u):
    return {gname[pw[u]]} | {g for g, m in members.items() if u in m}

def bits(u, p):
    mode, o, g = st[p]
    if u == o:
        return mode[1:4], "owner"
    if g in groups(u):
        return mode[4:7], "group"
    return mode[7:10], "other"

def access(u, path):
    parts = path.strip("/").split("/")
    for i in range(1, len(parts)):
        d = "/" + "/".join(parts[:i])
        if d in st and bits(u, d)[0][2] not in "xs":
            return False, False, "blocked"
    b, cls = bits(u, path)
    return b[0] == "r", b[1] == "w", cls

want = {}
for u in users:
    for p in files:
        want[(u, p)] = access(u, p)

lines = [l.strip() for l in open("matrix.csv", encoding="utf-8", errors="replace").read().replace("\r", "").split("\n") if l.strip()]
if not lines or lines[0].replace(" ", "") != "user,path,read,write":
    print("❌ the first line of matrix.csv must be: user,path,read,write")
    sys.exit(1)
got = {}
for l in lines[1:]:
    f = [x.strip() for x in l.split(",")]
    if len(f) != 4 or f[2] not in ("yes", "no") or f[3] not in ("yes", "no"):
        print("❌ the row '%s' is not user,path,yes|no,yes|no" % l[:60])
        sys.exit(1)
    k = (f[0], f[1])
    if k not in want:
        print("❌ the row for %s on %s is not one of the 30 combinations (user and path as written in the files)" % k)
        sys.exit(1)
    if k in got:
        print("❌ %s on %s appears twice" % k)
        sys.exit(1)
    got[k] = (f[2] == "yes", f[3] == "yes")
if len(got) != len(want):
    k = [x for x in want if x not in got][0]
    print("❌ matrix.csv has %d of 30 rows, for example %s on %s is missing" % (len(got), k[0], k[1]))
    sys.exit(1)
for k in want:
    r, w, cls = want[k]
    if got[k][0] != r or got[k][1] != w:
        what = "read" if got[k][0] != r else "write"
        why = {"blocked": "look at the directories above the file",
               "owner": "which of owner, group and other applies to this user, and which of them wins?",
               "group": "which of owner, group and other applies to this user, and where does their group membership come from?",
               "other": "which of owner, group and other applies to this user?"}[cls]
        print("❌ %s on %s: the %s answer is wrong (%s)" % (k[0], k[1], what, why))
        sys.exit(1)
print("✅ the 30-row matrix is right for all five users and six files")
PY
