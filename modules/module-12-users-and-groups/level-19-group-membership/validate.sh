#!/bin/bash
# Applies changes.csv (in order) to the original group and gshadow in Python,
# then compares the player's files byte for byte with the result.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
if [ ! -s .lm-state/group.orig ] || [ ! -s .lm-state/gshadow.orig ]; then
  echo "❌ the level's data is gone; type 'reset'"
  exit 1
fi
if ! cmp -s changes.csv .lm-state/changes.orig; then
  echo "❌ changes.csv was changed; it is the instruction list, type 'reset' to get it back"
  exit 1
fi
python3 - <<'PY'
import sys
def load(p):
    return [l.rstrip("\n").split(":") for l in open(p)]
def dump(rows):
    return "\n".join(":".join(r) for r in rows) + "\n"
def apply(rows, memcol):
    idx = {r[0]: r for r in rows}
    for l in open(".lm-state/changes.orig").read().splitlines()[1:]:
        a, usr, grp = l.split(",")
        mem = [m for m in idx[grp][memcol].split(",") if m]
        if a == "add" and usr not in mem:
            mem.append(usr)
        if a == "remove" and usr in mem:
            mem.remove(usr)
        idx[grp][memcol] = ",".join(mem)
    return rows
want = {"etc/group": dump(apply(load(".lm-state/group.orig"), 3)), "etc/gshadow": dump(apply(load(".lm-state/gshadow.orig"), 3))}
for path in ("etc/group", "etc/gshadow"):
    got = open(path).read()
    if got == want[path]:
        continue
    g, w = got.splitlines(), want[path].splitlines()
    if len(g) != len(w):
        print("❌ %s has %d lines, expected %d: groups must not be added or removed" % (path, len(g), len(w)))
        sys.exit(1)
    for a, b in zip(g, w):
        if a != b:
            name = b.split(":")[0]
            fa, fb = a.split(":"), b.split(":")
            if fa[0] != name:
                print("❌ %s: the lines changed order around %s" % (path, name))
            elif fa[:3] != fb[:3]:
                print("❌ %s: a field other than the member list changed in the line of %s" % (path, name))
            elif ",," in fa[3] or fa[3].startswith(",") or fa[3].endswith(","):
                print("❌ %s: the member list of %s has a stray comma ('%s')" % (path, name, fa[3]))
            else:
                print("❌ %s: the members of %s are '%s' but the changes imply '%s'" % (path, name, fa[3], fb[3]))
            sys.exit(1)
    print("❌ %s differs from the expected result" % path)
    sys.exit(1)
print("✅ etc/group and etc/gshadow match the reorg exactly")
PY
