#!/bin/bash
# Builds capture/utmp, a real binary utmp file (struct utmp, 384-byte records)
# that `who capture/utmp` reads. Sessions are random per setup: a few from
# 10.x, some from 172.16/192.168/public addresses, one from 110.x and one
# from 210.x (a sloppy "10\." match picks both up), and a console login.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p capture .lm-state
cat > TICKET.md <<'T'
# Incident 2026-11-04: jump host snapshot

Forensics saved the login records of jump-01 as capture/utmp. Which
sessions came from OUTSIDE the corporate 10.0.0.0/8 range? Fill in
outside_sessions.txt as `user tty host`, one session per line.
T
python3 - "$RANDOM$$" <<'PY'
import platform, random, struct, sys, calendar
# struct utmp is 384 bytes on x86_64 (32-bit session/time fields) but 400 bytes
# on aarch64 glibc (64-bit long/timeval): write the layout this machine's who reads.
if platform.machine() in ("aarch64", "arm64", "riscv64", "ppc64le"):
    FMT = "<h2xi32s4s32s256shhqqq4i20x4x"
else:
    FMT = "<h2xi32s4s32s256shhiii4i20x"
R = random.Random(int(sys.argv[1]))
users = R.sample(["alice", "bob", "carol", "dave", "erin", "frank", "grace", "heidi", "ivan", "judy", "mallory", "oscar"], 9)
inside = ["10.%d.%d.%d" % (R.randint(0, 40), R.randint(0, 250), R.randint(2, 250)) for _ in range(5)]
outside = ["172.%d.%d.%d" % (R.randint(16, 31), R.randint(0, 250), R.randint(2, 250)),
           "192.168.%d.%d" % (R.randint(0, 250), R.randint(2, 250)),
           "110.%d.%d.%d" % (R.randint(0, 250), R.randint(0, 250), R.randint(2, 250)),
           "210.%d.%d.%d" % (R.randint(0, 250), R.randint(0, 250), R.randint(2, 250)),
           "%d.%d.%d.%d" % (R.choice([34, 52, 81, 185, 203]), R.randint(0, 250), R.randint(0, 250), R.randint(2, 250))]
hosts = inside + outside
R.shuffle(hosts)
sess = []   # (user, tty, host)
for i, h in enumerate(hosts):
    sess.append((users[i % len(users)], "pts/%d" % i, h))
sess.insert(R.randint(0, len(sess)), (users[8], "tty1", ""))
base = calendar.timegm((2026, 11, 4, 8, 0, 0))
rec = b""
for i, (u, tty, h) in enumerate(sess):
    t = base + i * R.randint(300, 2400)
    ty = 7
    rec += struct.pack(FMT, ty, 1000 + i * 37, tty.encode(), (tty[-4:] if tty.startswith("pts") else "1").encode()[:4],
                       u.encode(), h.encode(), 0, 0, 0, t, 0, 0, 0, 0, 0)
open("capture/utmp", "wb").write(rec)
def inside_ten(h):
    return h.startswith("10.")
with open(".lm-state/expected", "w") as f:
    for u, tty, h in sess:
        if h and not inside_ten(h):
            f.write("%s %s %s\n" % (u, tty, h))
PY
