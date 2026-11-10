#!/bin/bash
# capture/wtmp: a real binary wtmp (the same record layout as utmp) that
# `last -f` reads. Timeline Aug 2026 .. Nov 2026, random per setup:
#   - one reboot in September (with a crash victim only it has)
#   - 3-5 reboots in October: some clean shutdowns (sessions end "down"),
#     some crashes (sessions still open at the reboot show "crash")
#   - one reboot on 2 November, and a session still logged in at the end.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p capture .lm-state
cat > TICKET.md <<'T'
# db-02: unexpected reboots

capture/wtmp is the login history of db-02 (a copy of /var/log/wtmp).
How many times did it boot in October 2026, and which users were thrown out
of their sessions by a crash during those October reboots?
T
python3 - "$RANDOM$$" <<'PY'
import calendar, platform, random, struct, sys
R = random.Random(int(sys.argv[1]))
if platform.machine() in ("aarch64", "arm64", "riscv64", "ppc64le"):
    FMT = "<h2xi32s4s32s256shhqqq4i20x4x"
else:
    FMT = "<h2xi32s4s32s256shhiii4i20x"
def ts(m, d, h, mi):
    return calendar.timegm((2026, m, d, h, mi, 0))
recs = []          # (time, seq, type, pid, line, id, user, host)
seq = [0]
def add(t, ty, pid, line, ident, user, host):
    seq[0] += 1
    recs.append((t, seq[0], ty, pid, line, ident, user, host))
pool = R.sample(["alice", "bob", "carol", "dave", "erin", "frank", "grace", "heidi", "ivan", "judy"], 8)
sep_victim = pool[0]
oct_pool = pool[1:]
ttyn = [0]
def login(t, user, out=None):
    ttyn[0] += 1
    line = "pts/%d" % (ttyn[0] % 9)
    add(t, 7, 2000 + ttyn[0], line, line[-4:], user, "10.0.%d.%d" % (R.randint(0, 9), R.randint(2, 200)))
    if out:
        add(out, 8, 2000 + ttyn[0], line, line[-4:], "", "")
    return line
KERNEL = "6.8.0-45-generic"
add(ts(8, 20, 6, 10), 2, 0, "~", "~~", "reboot", KERNEL)
for _ in range(3):
    d = R.randint(21, 31); h = R.randint(8, 15)
    login(ts(8, d, h, 5), R.choice(oct_pool), ts(8, d, h + 2, 30))
login(ts(9, 10, 9, 0), sep_victim)
add(ts(9, 12, 3, R.randint(5, 55)), 2, 0, "~", "~~", "reboot", KERNEL)
n_oct = R.randint(3, 5)
days = sorted(R.sample(range(4, 28), n_oct))
crash_users = set()
for i, d in enumerate(days):
    for _ in range(R.randint(1, 2)):
        dd = max(1, d - R.randint(1, 3))
        h = R.randint(8, 14)
        login(ts(10, dd, h, 15), R.choice(oct_pool), ts(10, dd, h + 3, 20))
    clean = (i % 2 == 1)           # the first reboot is always a crash
    opens = R.sample(oct_pool, R.randint(1, 2))
    for u in opens:
        login(ts(10, d, 1, R.randint(1, 30)), u)
    t = ts(10, d, 3, R.randint(31, 59))
    if clean:
        add(t - 60, 1, 0, "~", "~~", "shutdown", KERNEL)
    else:
        crash_users.update(opens)
    add(t + 45, 2, 0, "~", "~~", "reboot", KERNEL)
login(ts(11, 1, 17, 0), pool[1], ts(11, 1, 18, 0))
login(ts(11, 2, 1, 10), pool[2])
add(ts(11, 2, 2, 31), 2, 0, "~", "~~", "reboot", KERNEL)
login(ts(11, 3, 9, 30), pool[3])
recs.sort(key=lambda r: (r[0], r[1]))
out = b""
for t, _, ty, pid, line, ident, user, host in recs:
    out += struct.pack(FMT, ty, pid, line.encode(), ident.encode(), user.encode(), host.encode(), 0, 0, 0, t, 0, 0, 0, 0, 0)
open("capture/wtmp", "wb").write(out)
open(".lm-state/reboots", "w").write("%d\n" % n_oct)
open(".lm-state/crash_users", "w").write("".join(u + "\n" for u in sorted(crash_users)))
PY
