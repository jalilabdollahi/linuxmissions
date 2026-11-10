#!/bin/bash
# Compares etc/passwd, shadow, group, gshadow, subuid/subgid, the homes and the
# sudoers.d file with what TICKET.md asks for.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
if [ ! -s .lm-state/orig/passwd ] || [ ! -s .lm-state/hash ] || [ ! -x bin/visudo ]; then
  echo "❌ the level's data is gone; type 'reset'"
  exit 1
fi
if ! cksum etc/login.defs etc/default/useradd etc/skel/.bashrc etc/skel/.profile etc/skel/.bash_logout etc/skel/.config/corp/proxy.conf etc/sudoers.d/README 2>/dev/null | cmp -s - .lm-state/cfg.sum; then
  echo "❌ a configuration file (login.defs, default/useradd, skel or sudoers.d/README) was changed; the ticket does not ask for that"
  exit 1
fi
python3 - <<'PY'
import os, stat, subprocess, sys

O = ".lm-state/orig/"
HASH = open(".lm-state/hash").read().strip()
def lines(p):
    return open(p).read().split("\n")[:-1] if os.path.exists(p) else []
def fail(msg):
    print("❌ " + msg)
    sys.exit(1)
people = [("ana", 1600, "Ana Ribeiro"), ("ben", 1311, "Ben Okafor"), ("cara", 1601, "Cara Lindholm")]

# ---- passwd
op, np_ = lines(O + "passwd"), lines("etc/passwd")
pw = {l.split(":")[0]: l for l in np_}
for name, uid, full in people:
    if name not in pw:
        fail("%s has no account in etc/passwd yet" % name)
    if len([l for l in np_ if l.split(":")[0] == name]) > 1:
        fail("%s appears twice in etc/passwd" % name)
    f = pw[name].split(":")
    if name != "ben" and int(f[2]) != uid:
        if 1500 <= int(f[2]) <= 1599:
            fail("%s got UID %s, inside the range 1500-1599 that the ticket reserves; the next free UID is 1600" % (name, f[2]))
        fail("%s has UID %s, expected %d (next UIDs from 1600, in ticket order)" % (name, f[2], uid))
    if name == "ben" and f[2] != "1311":
        fail("ben's UID changed: the account must be re-enabled, not recreated")
    want = "%s:x:%d:%d:%s:/home/%s:/bin/bash" % (name, uid, uid, full, name)
    if pw[name] != want:
        if f[6] != "/bin/bash":
            fail("%s's login shell is %s, the ticket says /bin/bash" % (name, f[6]))
        if f[4] != full:
            fail("%s's comment is '%s', expected the full name '%s'" % (name, f[4], full))
        fail("the passwd line of %s is not as expected (private group, home or fields): %s" % (name, pw[name]))
others_old = [l for l in op if l.split(":")[0] != "ben"]
others_new = [l for l in np_ if l.split(":")[0] not in ("ana", "ben", "cara")]
if others_old != others_new:
    fail("etc/passwd changed for someone who is not on the ticket")

# ---- group / gshadow
def gtable(p):
    t = {}
    order = []
    for l in lines(p):
        f = l.split(":")
        t[f[0]] = f
        order.append(f[0])
    return t, order
for path, base, memcol in (("etc/group", "group", 3), ("etc/gshadow", "gshadow", 3)):
    og, _ = gtable(O + base)
    ng, order = gtable(path)
    for name, uid, full in people:
        if name == "ben":
            continue
        want = ["%s" % name, "x" if base == "group" else "!", str(uid) if base == "group" else "", ""]
        if name not in ng:
            fail("%s has no private group %s in %s" % (name, name, path))
        if base == "group" and ng[name][2] != str(uid):
            fail("the group of %s has GID %s in etc/group, expected %d" % (name, ng[name][2], uid))
        if base == "gshadow" and ng[name][:3] != [name, "!", ""]:
            fail("the gshadow entry of %s is not 'name:!::' in %s" % (name, path))
    extra = [n for n in ng if n not in og and n not in ("ana", "cara")]
    if extra:
        fail("%s has a new group %s that is not on the ticket" % (path, extra[0]))
    for n in og:
        if n not in ng:
            fail("%s: the group %s is gone" % (path, n))
        if n in ("engineers", "docker"):
            want = set(m for m in og[n][3].split(",") if m) | {"ana", "ben", "cara"}
            got = [m for m in ng[n][3].split(",")]
            if "" in got and len(got) > 1 or ng[n][3].startswith(",") or ng[n][3].endswith(","):
                fail("%s: the member list of %s has a stray comma" % (path, n))
            if len(set(got)) != len(got):
                fail("%s: %s lists a member twice" % (path, n))
            if set(got) != want:
                miss = sorted(want - set(got))
                if miss:
                    fail("%s: %s is missing %s as a member" % (path, n, miss[0]))
                fail("%s: %s has an unexpected member (%s)" % (path, n, sorted(set(got) - want)[0]))
            if ng[n][:3] != og[n][:3]:
                fail("%s: fields other than the members changed for %s" % (path, n))
        elif ng[n] != og[n]:
            fail("%s: the entry of %s changed, but it is not part of the ticket" % (path, n))

# ---- shadow
os_, ns = lines(O + "shadow"), lines("etc/shadow")
nsd = {l.split(":")[0]: l.split(":") for l in ns}
osd = {l.split(":")[0]: l.split(":") for l in os_}
for name, uid, full in people:
    if name not in nsd:
        fail("%s has no entry in etc/shadow" % name)
    f = nsd[name]
    if name == "ben":
        o = osd["ben"]
        if f[1].startswith("!"):
            fail("ben's password is still locked (a ! in front of the hash)")
        if f[1] != o[1].lstrip("!"):
            fail("ben's own password hash must stay (unlock it, do not replace it)")
        if f[7] != "":
            fail("ben's account still has an expiry date (shadow field 8 is %s); it expired when he left" % f[7])
        if f[2] != "0":
            fail("ben's last password change is %s: he must change his password at first login (day 0)" % f[2])
        if [f[3], f[4], f[5], f[6], f[8]] != [o[3], o[4], o[5], o[6], o[8]]:
            fail("ben's password aging fields changed; only the lock, the expiry and the last-change day should")
    else:
        if f[1] != HASH:
            fail("the password of %s is not the initial hash from the ticket" % name)
        if f[2] != "0":
            fail("%s must change the password at first login: the last-change day is %s, expected 0" % (name, f[2]))
        if f[3:] != ["1", "90", "7", "", "", ""]:
            fail("the password aging fields of %s are not the defaults of login.defs (min 1, max 90, warn 7)" % name)
for n in osd:
    if n != "ben" and n not in nsd:
        fail("the shadow entry of %s is gone" % n)
    if n != "ben" and ":".join(nsd[n]) != ":".join(osd[n]):
        fail("the shadow entry of %s changed, but that person is not on the ticket" % n)
if len(ns) != len(os_) + 2:
    fail("etc/shadow has %d lines, expected %d" % (len(ns), len(os_) + 2))

# ---- subuid / subgid
for kind in ("subuid", "subgid"):
    orig = lines(O + kind)
    now = lines("etc/" + kind)
    for l in orig:
        if l not in now:
            fail("etc/%s: the line '%s' was changed or removed" % (kind, l))
    have = {}
    rng = []
    for l in now:
        f = l.split(":")
        if len(f) != 3 or not f[1].isdigit() or not f[2].isdigit():
            fail("etc/%s: '%s' is not user:start:count" % (kind, l))
        rng.append((int(f[1]), int(f[2]), f[0]))
        if l not in orig:
            if f[0] not in ("ana", "ben", "cara"):
                fail("etc/%s: a new line for %s, who is not on the ticket" % (kind, f[0]))
            have.setdefault(f[0], []).append((int(f[1]), int(f[2])))
    for name in ("ana", "ben", "cara"):
        got = have.get(name, [])
        if not got:
            fail("%s has no range in etc/%s" % (name, kind))
        if len(got) > 1:
            fail("%s has %d ranges in etc/%s, exactly one is wanted" % (name, len(got), kind))
        if got[0][1] != 65536 or got[0][0] < 100000:
            fail("%s's range in etc/%s must be 65536 IDs starting at 100000 or above" % (name, kind))
    rng.sort()
    for a, b in zip(rng, rng[1:]):
        if b[0] < a[0] + a[1]:
            fail("etc/%s: the ranges of %s and %s overlap" % (kind, a[2], b[2]))

# ---- homes
skel = "etc/skel"
def tree(root):
    out = {}
    for d, ds, fs in os.walk(root):
        for n in ds + fs:
            p = os.path.join(d, n)
            rel = os.path.relpath(p, root)
            out[rel] = None if os.path.isdir(p) else open(p, "rb").read()
    return out
st = tree(skel)
for name in ("ana", "cara"):
    h = "home/" + name
    if not os.path.isdir(h):
        fail("%s has no home directory %s" % (name, h))
    m = stat.S_IMODE(os.stat(h).st_mode)
    if m != 0o750:
        fail("the home of %s has mode %04o, expected 0750" % (name, m))
    if tree(h) != st:
        fail("the home of %s does not hold exactly what /etc/skel holds (.bashrc, .profile, .bash_logout, .config/corp/proxy.conf)" % name)
cur = subprocess.run("cd home/ben && find . -type f -exec cksum {} + | LC_ALL=C sort; ls -ld . | cut -c1-10", shell=True, capture_output=True, text=True).stdout
if cur != open(".lm-state/ben.home").read():
    fail("ben's existing home was changed or replaced: it should stay exactly as it is")

# ---- sudo
if not os.path.exists("etc/sudoers.d/engineers"):
    other = [n for n in os.listdir("etc/sudoers.d") if n.startswith("engineers")]
    if other:
        fail("etc/sudoers.d/%s is ignored by sudo (names with a dot or ~ are skipped); the file must be called engineers" % other[0])
    fail("etc/sudoers.d/engineers does not exist yet")
m = stat.S_IMODE(os.stat("etc/sudoers.d/engineers").st_mode)
if m != 0o440:
    fail("etc/sudoers.d/engineers has mode %04o, sudo files must be 0440" % m)
import re
rules = [l.strip() for l in open("etc/sudoers.d/engineers") if l.strip() and not l.strip().startswith("#")]
if rules != [r for r in rules if re.match(r"^%engineers\s+ALL\s*=\s*\(ALL(:ALL)?\)\s+ALL$", r)] or len(rules) != 1:
    fail("etc/sudoers.d/engineers should hold exactly one rule: %engineers ALL=(ALL:ALL) ALL")
r = subprocess.run(["bin/visudo", "-c"], capture_output=True, text=True)
if r.returncode != 0:
    fail("visudo -c is not happy: %s" % (r.stdout + r.stderr).strip().splitlines()[-1])
print("✅ ana and cara are created, ben is re-enabled, groups, homes, sudo, first-login password change and container ranges all match the ticket")
PY
