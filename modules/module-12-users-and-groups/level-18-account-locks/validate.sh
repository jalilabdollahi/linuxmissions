#!/bin/bash
# The four leavers (found by the ticket via GECOS) have exactly one ! in front
# of their original hash and shadow field 8 = 1; every other shadow line and
# all of etc/passwd are unchanged; no "!!".
SANDBOX="$1"
cd "$SANDBOX" || exit 1
if [ ! -s .lm-state/leavers ] || [ ! -s .lm-state/shadow.orig ]; then
  echo "❌ the level's data is gone; type 'reset'"
  exit 1
fi
if ! cmp -s etc/passwd .lm-state/passwd.orig; then
  echo "❌ etc/passwd was changed; locking and expiring only touches etc/shadow"
  exit 1
fi
python3 - <<'PY'
import sys
leavers = open(".lm-state/leavers").read().split()
orig = [l.rstrip("\n") for l in open(".lm-state/shadow.orig")]
now = [l.rstrip("\n") for l in open("etc/shadow")]
if len(orig) != len(now):
    print("❌ etc/shadow has %d lines, it had %d: nothing is to be added or removed" % (len(now), len(orig)))
    sys.exit(1)
for o, n in zip(orig, now):
    of, nf = o.split(":"), n.split(":")
    name = of[0]
    if nf[0] != name:
        print("❌ the order of etc/shadow changed around %s" % name)
        sys.exit(1)
    if name not in leavers:
        if o != n:
            if name == "deploy":
                print("❌ the shared deploy account was changed; the ticket says not to touch it (a comment that mentions a leaver's address is not the leaver)")
            else:
                print("❌ the shadow line of %s changed, but that person is not on the ticket" % name)
            sys.exit(1)
        continue
    if len(nf) != len(of):
        print("❌ the shadow line of %s has the wrong number of fields" % name)
        sys.exit(1)
    base = of[1].lstrip("!")
    if nf[1].startswith("!!"):
        print("❌ the password of %s has two ! in front; one is enough (and a second lock hides the hash)" % name)
        sys.exit(1)
    if not nf[1].startswith("!"):
        print("❌ %s is not locked: the password field has no ! in front" % name)
        sys.exit(1)
    if nf[1][1:] != base:
        print("❌ the original password hash of %s is not intact behind the !" % name)
        sys.exit(1)
    if nf[7] != "1":
        print("❌ the account of %s does not expire yet (expiry field is '%s', expected day 1)" % (name, nf[7]))
        sys.exit(1)
    for i in (2, 3, 4, 5, 6, 8):
        if nf[i] != of[i]:
            print("❌ %s: a field other than the lock and the expiry changed (field %d)" % (name, i + 1))
            sys.exit(1)
print("✅ %d leavers are locked and expired, every other account is untouched" % len(leavers))
PY
