#!/bin/bash
# capture/w.txt: output of `w` on a build box with 9-12 sessions. The IDLE
# column uses procps' formats: "45.00s" (under a minute), "3:12" (min:sec),
# "1:05m" (hours:min) and "2days". Random per setup; some users have two
# sessions with different idle times.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p capture .lm-state
cat > TICKET.md <<'T'
# Reboot of build-04 tonight

We reboot at 22:00. Warn everyone who is working right now: a session that
has been idle for 10 minutes or more is considered abandoned. capture/w.txt
is the output of `w` taken a minute ago.
T
python3 - "$RANDOM$$" <<'PY'
import random, sys
R = random.Random(int(sys.argv[1]))
users = R.sample(["alice", "bob", "carol", "dave", "erin", "frank", "grace", "heidi", "ivan", "judy", "ken", "lena"], 8)

def fmt(sec):          # procps-ng w: print_time_ival7
    if sec >= 48 * 3600:
        return "%2ddays" % (sec // 86400)
    if sec >= 3600:
        return "%2d:%02dm" % (sec // 3600, (sec % 3600) // 60)
    if sec >= 60:
        return "%2d:%02d" % (sec // 60, sec % 60)
    return "%d.%02ds" % (sec, R.randint(0, 99))

# (user, idle seconds). Traps: 1:05m (an hour, numerically small), 2days,
# 9:59 and 10:00 at the edge, a repeated user with a fresh and a stale session.
rows = []
u = users[:]
rows.append((u[0], R.randint(1, 50)))            # seconds
rows.append((u[1], R.randint(61, 599)))          # min:sec, under 10
rows.append((u[2], 3600 + R.randint(60, 600)))   # 1:xxm  -> stale
rows.append((u[3], 3 * 86400))                   # days   -> stale
rows.append((u[4], 599))                         # 9:59   -> fresh
rows.append((u[5], 600))                         # 10:00  -> stale
rows.append((u[6], R.randint(1900, 3500)))       # 31:xx  -> stale
rows.append((u[6], R.randint(2, 40)))            # same user, fresh session
rows.append((u[7], R.randint(3700, 7000)))       # hours  -> stale
rows.append((u[7], R.randint(700, 1800)))        # same user, stale
for _ in range(R.randint(0, 2)):
    rows.append((R.choice(u[:4]), R.choice([30, 90, 400, 5000, 90000])))
R.shuffle(rows)
whats = ["-bash", "vim main.c", "make -j8", "ssh deploy-02", "tail -f build.log", "-zsh", "htop", "python3 gen.py", "less /var/log/syslog"]
froms = ["10.0.4.12", "10.0.4.15", "10.0.7.31", "192.168.20.5", "-", "10.0.4.40"]
logins = ["09:15", "10:42", "Mon10", "Tue14", "14:02", "11:30", "08:05", "Sat09", "13:48"]
out = [" 21:47:03 up 41 days,  3:12,  %d users,  load average: 2.%02d, 1.%02d, 0.%02d" % (len(rows), R.randint(0, 99), R.randint(0, 99), R.randint(0, 99)),
       "USER     TTY      FROM             LOGIN@   IDLE   JCPU   PCPU WHAT"]
for i, (user, sec) in enumerate(rows):
    out.append("%-8s pts/%-3d %-16s %-8s %7s %6s %6s %s" % (user, i, R.choice(froms), R.choice(logins), fmt(sec),
                "%d.%02ds" % (R.randint(0, 40), R.randint(0, 99)), "%d.%02ds" % (R.randint(0, 3), R.randint(0, 99)), R.choice(whats)))
open("capture/w.txt", "w").write("\n".join(out) + "\n")
with open(".lm-state/expected", "w") as f:
    for user in sorted({x for x, s in rows if s < 600}):
        f.write(user + "\n")
PY
