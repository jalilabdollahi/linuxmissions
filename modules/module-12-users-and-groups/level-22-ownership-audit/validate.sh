#!/bin/bash
# Runs chown-plan.sh (cwd restored/, bin/chown first in PATH) and compares the
# recorded (path, user, group) calls with what mapping BY NAME gives; checks
# unmapped.txt the same way. The inputs must be unchanged.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
if [ ! -s .lm-state/in/listing ] || [ ! -x bin/chown ]; then
  echo "❌ the level's data is gone; type 'reset'"
  exit 1
fi
IN=.lm-state/in
if ! cmp -s old/etc/passwd $IN/old-passwd || ! cmp -s old/etc/group $IN/old-group || ! cmp -s etc/passwd $IN/new-passwd || ! cmp -s etc/group $IN/new-group || ! cmp -s restore-listing.txt $IN/listing; then
  echo "❌ one of the evidence files (old/etc/*, etc/passwd, etc/group, restore-listing.txt) was changed; type 'reset' to get them back"
  exit 1
fi
if [ ! -s chown-plan.sh ]; then
  echo "❌ chown-plan.sh does not exist yet (or is empty)"
  exit 1
fi
if [ ! -f unmapped.txt ]; then
  echo "❌ unmapped.txt does not exist yet"
  exit 1
fi
: > .lm-state/chown.log
( cd restored && PATH="$SANDBOX/bin:$PATH" timeout 20 bash ../chown-plan.sh >/dev/null 2>"$SANDBOX/.lm-state/plan.err" )
prc=$?
if [ $prc -ne 0 ]; then
  echo "❌ chown-plan.sh fails when run from restored/ (exit $prc): $(head -n 1 .lm-state/plan.err | cut -c1-100)"
  exit 1
fi
python3 - <<'PY'
import sys
IN = ".lm-state/in/"
def table(p, col):
    d = {}
    for l in open(p):
        f = l.rstrip("\n").split(":")
        if len(f) > 2:
            d[f[2]] = f[0]
    return d
ou, og = table(IN + "old-passwd", 2), table(IN + "old-group", 2)
nu = set(table(IN + "new-passwd", 2).values()); ng = set(table(IN + "new-group", 2).values())
want = {}
unm = set()
for l in open(IN + "listing").read().splitlines():
    f = l.split(None, 7)
    uid, gid, path = f[2], f[3], f[7]
    u, g = ou[uid], og[gid]
    if u not in nu: unm.add("user " + u)
    if g not in ng: unm.add("group " + g)
    spec = (u if u in nu else None, g if g in ng else None)
    if spec != (None, None):
        want[path] = spec
got = {}
for line in open(".lm-state/chown.log", encoding="utf-8", errors="replace").read().split("\n"):
    if not line:
        continue
    args = [a for a in line.split("\x1f") if a != ""]
    args = [a for a in args if a not in ("-h", "-R", "-f", "-v", "-c", "--")]
    spec, files = args[0], args[1:]
    if ":" in spec:
        u, g = spec.split(":", 1)
    else:
        u, g = spec, None
    if g == "" and u:
        print("❌ 'chown %s' (a trailing colon) sets the user's login group on the new server, not the group from the old one" % spec)
        sys.exit(1)
    for p in files:
        if p in got:
            print("❌ the plan touches '%s' more than once" % p)
            sys.exit(1)
        got[p] = (u or None, g or None)
for p in sorted(got):
    if p not in want:
        listed = any(l.split(None, 7)[7] == p for l in open(IN + "listing").read().splitlines())
        if listed:
            print("❌ the plan changes '%s', but neither its user nor its group exists on app-09: that path gets no line" % p)
        else:
            print("❌ the plan touches '%s', which is not a path in the listing (quoting? spaces and apostrophes split a path)" % p)
        sys.exit(1)
for p in sorted(want):
    if p not in got:
        print("❌ there is no chown for '%s' (%d of %d paths are covered)" % (p, len(got), len(want)))
        sys.exit(1)
for p in sorted(want):
    if got[p] != want[p]:
        wu, wg = want[p]
        gu, gg = got[p]
        if gu != wu and wu is None:
            print("❌ '%s': its owner does not exist on app-09, so only the group should be changed (you also set user %s)" % (p, gu))
        elif gg != wg and wg is None:
            print("❌ '%s': its group does not exist on app-09, so only the user should be changed (you also set group %s)" % (p, gg))
        elif gu != wu:
            print("❌ '%s': the user is not the one the old server's passwd names for that UID (%s given)" % (p, gu))
        else:
            print("❌ '%s': the group is not the one the old server's group file names for that GID (%s given)" % (p, gg))
        sys.exit(1)
lines = [l.strip() for l in open("unmapped.txt", encoding="utf-8", errors="replace").read().replace("\r", "").split("\n") if l.strip()]
gotu = set(" ".join(l.split()) for l in lines)
if len(lines) != len(gotu):
    print("❌ unmapped.txt lists an owner more than once")
    sys.exit(1)
for l in sorted(gotu - unm):
    print("❌ unmapped.txt: '%s' is not an owner from the listing that is missing on app-09" % l)
    sys.exit(1)
for l in sorted(unm - gotu):
    print("❌ unmapped.txt is missing '%s'" % l)
    sys.exit(1)
print("✅ the plan restores %d paths by name and unmapped.txt names the %d owners app-09 does not have" % (len(want), len(unm)))
PY
