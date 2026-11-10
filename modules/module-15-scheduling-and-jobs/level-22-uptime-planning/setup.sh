#!/bin/bash
# The build box is powered off every night, so the 02:00 job silently skips.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

python3 - <<'PY'
import datetime as dt

KERNEL = "6.8.0-45-generic"
T = lambda m, d, h, mi: dt.datetime(2026, m, d, h, mi)
# One tuple per power-on: (boot time, end). End is the time of the shutdown record,
# "crash" when the box died without one, or None while it is still up.
sessions = [
    (T(10, 24, 7, 4), T(10, 24, 22, 0)), (T(10, 25, 7, 7), T(10, 25, 22, 0)),
    (T(10, 26, 7, 1), T(10, 26, 22, 0)), (T(10, 27, 7, 4), T(10, 27, 22, 0)),
    (T(10, 28, 7, 7), T(10, 28, 22, 0)), (T(10, 29, 7, 1), T(10, 29, 22, 0)),
    (T(10, 30, 7, 4), T(10, 31, 22, 0)),                     # left on overnight
    (T(11, 1, 7, 1), T(11, 1, 22, 0)), (T(11, 2, 7, 4), T(11, 2, 22, 0)),
    (T(11, 3, 7, 7), T(11, 3, 22, 0)),
    (T(11, 4, 7, 1), "crash"),                               # dead until Nov 6
    (T(11, 6, 7, 55), T(11, 6, 22, 0)),
    (T(11, 7, 7, 1), T(11, 8, 22, 0)),                       # left on overnight
    (T(11, 9, 7, 7), T(11, 9, 22, 0)),
    (T(11, 10, 7, 1), None),
]

def fmt(t):
    return t.strftime("%a %b ") + f"{t.day:2d} " + t.strftime("%H:%M")

def dur(a, b):
    m = int((b - a).total_seconds()) // 60
    d, h, mi = m // 1440, m % 1440 // 60, m % 60
    return f"({d}+{h:02d}:{mi:02d})" if d else f"({h:02d}:{mi:02d})"

out = []
for i in range(len(sessions) - 1, -1, -1):
    boot, end = sessions[i]
    nxt = sessions[i + 1][0] if i + 1 < len(sessions) else None
    if end is None:
        tail = "  still running"
    elif end == "crash":
        tail = f" - crash  {dur(boot, nxt)}"
    else:
        tail = f" - {end:%H:%M}  {dur(boot, end)}"
    out.append(f"runlevel (to lvl 5)   {KERNEL} {fmt(boot)}{tail}")
    out.append(f"reboot   system boot  {KERNEL} {fmt(boot)}{tail}")
    if i > 0 and sessions[i - 1][1] != "crash":
        prev_end = sessions[i - 1][1]
        out.append(f"shutdown system down  {KERNEL} {fmt(prev_end)} - {boot:%H:%M}  {dur(prev_end, boot)}")
out += ["", "wtmp begins Sat Oct 24 07:04:09 2026"]
open("boot-history.txt", "w").write("\n".join(out) + "\n")
PY

cat > crontab.txt <<'EOF'
# build box bb-02, user builder
MAILTO=builders@example.com
*/10 * * * * /opt/build/bin/queue-heartbeat
0 2 * * * /opt/build/nightly.sh --full >> /var/log/build/nightly.log 2>&1
30 8 * * 1-5 /opt/build/bin/send-morning-summary
EOF

cat > anacrontab <<'EOF'
# /etc/anacrontab: configuration file for anacron
SHELL=/bin/sh
HOME=/root
LOGNAME=root

# These replace cron's entries
1	5	cron.daily	run-parts --report /etc/cron.daily
7	10	cron.weekly	run-parts --report /etc/cron.weekly
@monthly	15	cron.monthly	run-parts --report /etc/cron.monthly
EOF

cat > TICKET.txt <<'EOF'
BLD-77  nightly build did not run (again)

bb-02 is switched off at 22:00 and on again at about 07:00 to save power, so the 02:00
nightly build in crontab.txt never runs on those nights. boot-history.txt is
`last -x` from the box, taken on 2026-11-10 at 08:00 (newest record first).

Two nights the box was left on. On Nov 4 the box crashed: monitoring lost it at
23:40 and nobody powered it on until Nov 6 (a crash leaves no shutdown record).

1. missed.txt: the dates (YYYY-MM-DD, one per line) of the last 14 02:00 runs, 2026-10-28
   to 2026-11-10, when the box was down at 02:00 and the job therefore did not run.
2. Move the job to anacrontab so it catches up after boot: run every day, 5 to 15
   minutes after anacron starts, with its own job identifier and the same command.
   Take it out of crontab.txt; the other jobs there stay as they are.
EOF
