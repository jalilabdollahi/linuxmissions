#!/bin/bash
# Per file: the original lines are intact and in order; omar, pavel, nina each
# have exactly one 65536 range starting >= 100000; no two ranges overlap.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
if [ ! -s .lm-state/subuid.orig ] || [ ! -s .lm-state/subgid.orig ]; then
  echo "❌ the level's data is gone; type 'reset'"
  exit 1
fi
python3 - <<'PY'
import sys
NEW = ["omar", "pavel", "nina"]
for kind in ("subuid", "subgid"):
    orig = open(".lm-state/%s.orig" % kind).read().splitlines()
    now = open("etc/%s" % kind).read().splitlines()
    rest = list(now)
    for line in orig:
        if line not in rest:
            print("❌ etc/%s: the line '%s' was changed or removed" % (kind, line))
            sys.exit(1)
    # the originals must still be in the same order
    pos = [now.index(l) for l in orig]
    if pos != sorted(pos):
        print("❌ etc/%s: existing lines changed order" % kind)
        sys.exit(1)
    added = [l for l in now if l not in orig]
    if len(added) != len(now) - len(orig):
        print("❌ etc/%s: a line is duplicated" % kind)
        sys.exit(1)
    ranges = []
    have = {}
    for l in now:
        f = l.split(":")
        if len(f) != 3 or not f[1].isdigit() or not f[2].isdigit():
            print("❌ etc/%s: '%s' is not in user:start:count form" % (kind, l))
            sys.exit(1)
        ranges.append((int(f[1]), int(f[2]), f[0], l in orig))
        if l not in orig:
            if f[0] not in NEW:
                print("❌ etc/%s: a new line for %s, who is not on the ticket" % (kind, f[0]))
                sys.exit(1)
            have.setdefault(f[0], []).append((int(f[1]), int(f[2])))
        elif f[0] in NEW:
            have.setdefault(f[0], []).append((int(f[1]), int(f[2])))
    for u in NEW:
        n = len(have.get(u, []))
        if n == 0:
            print("❌ %s has no range in etc/%s yet" % (u, kind))
            sys.exit(1)
        if n > 1:
            print("❌ %s has %d ranges in etc/%s, exactly one is wanted" % (u, n, kind))
            sys.exit(1)
        s, c = have[u][0]
        if c != 65536:
            print("❌ %s's range in etc/%s has %d IDs, not 65536" % (u, kind, c))
            sys.exit(1)
        if s < 100000:
            print("❌ %s's range in etc/%s starts at %d, below 100000" % (u, kind, s))
            sys.exit(1)
    ranges.sort()
    for (s1, c1, u1, _), (s2, c2, u2, _) in zip(ranges, ranges[1:]):
        if s2 < s1 + c1:
            print("❌ etc/%s: the ranges of %s (%d-%d) and %s (starting %d) overlap" % (kind, u1, s1, s1 + c1 - 1, u2, s2))
            sys.exit(1)
print("✅ omar, pavel and nina each have one 65536 range in etc/subuid and etc/subgid, with no overlaps")
PY
