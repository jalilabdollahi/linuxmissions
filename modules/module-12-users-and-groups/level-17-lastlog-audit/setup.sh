#!/bin/bash
# app-07: etc/passwd (system accounts, one UID-999 service, nobody, ~15
# people) and lastlog.txt in the real lastlog layout (fixed-width columns,
# "**Never logged in**", dates like "Aug  4" with two spaces, mixed UTC
# offsets). People are shuffled into recent / dormant / never / absent from
# lastlog, plus four logins that sit right on the 90-day line once converted
# to UTC. TICKET.md has the rules.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p etc .lm-state

python3 - "$RANDOM$$" <<'PY'
import random, sys
from datetime import datetime, timedelta, timezone

R = random.Random(int(sys.argv[1]))
NOW = datetime(2026, 11, 10, 9, 0, tzinfo=timezone.utc)

people = [("anya", "Anya Petrova"), ("marco", "Marco Bellini"), ("tkaur", "Tejinder Kaur"),
          ("lwong", "Lena Wong"), ("jbrooks", "Jamal Brooks"), ("fatima", "Fatima Haddad"),
          ("sokeefe", "Sean O'Keefe"), ("rsato", "Rin Sato"), ("mdiaz", "Maria Diaz"),
          ("pnovak", "Pavel Novak"), ("ychen", "Yu Chen"), ("asaleh", "Ahmed Saleh"),
          ("ikowal", "Ida Kowalska"), ("dmoore", "Dana Moore"), ("vrossi", "Valentina Rossi"),
          ("bli", "Bo Li")]
R.shuffle(people)
people = people[:15]
# kinds: 4 boundary cases, 5 recent, 3 old, 2 never, 1 absent from lastlog
kinds = ["edge_keep", "edge_dormant", "edge_cutoff_utc", "edge_fresh_utc"] + ["recent"] * 5 + ["old"] * 3 + ["never"] * 2 + ["absent"]
R.shuffle(kinds)

offsets = [0, 0, 60, 120, -300, -480, 330]
def tz(minutes):
    return timezone(timedelta(minutes=minutes))

def at_local(day, hour, minute, off):
    return datetime(2026, 8, day, hour, minute, 7, tzinfo=tz(off))

login = {}
for (u, _), k in zip(people, kinds):
    off = R.choice(offsets)
    if k == "edge_keep":        # Aug 12 23:30 -0500 = Aug 13 04:30 UTC: still in the window
        login[u] = at_local(12, 23, 30, -300)
    elif k == "edge_dormant":   # Aug 13 01:30 +0200 = Aug 12 23:30 UTC: on the line
        login[u] = at_local(13, 1, 30, 120)
    elif k == "edge_cutoff_utc":
        login[u] = at_local(12, R.randint(0, 23), R.randint(0, 59), 0)
    elif k == "edge_fresh_utc":
        login[u] = at_local(13, 0, R.randint(0, 40), 0)
    elif k == "recent":
        login[u] = (NOW - timedelta(days=R.randint(1, 85), hours=R.randint(0, 20))).astimezone(tz(off))
    elif k == "old":
        login[u] = (NOW - timedelta(days=R.randint(110, 520), hours=R.randint(0, 20))).astimezone(tz(off))
    elif k == "never":
        login[u] = None
    elif k == "absent":
        pass

def fmt(dt):
    return dt.strftime("%a %b %e %H:%M:%S %z %Y")

rows = []   # (name, port, from, when or None)
passwd = ["root:x:0:0:root:/root:/bin/bash", "daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin",
          "www-data:x:33:33:www-data:/var/www:/usr/sbin/nologin",
          "sshd:x:105:65534::/run/sshd:/usr/sbin/nologin"]
rows += [("root", "tty1", "", NOW - timedelta(days=2)), ("daemon", "", "", None), ("www-data", "", "", None), ("sshd", "", "", None)]
passwd.append("gitlab-runner:x:999:999:GitLab Runner:/home/gitlab-runner:/bin/bash")
rows.append(("gitlab-runner", "pts/1", "10.0.8.21", datetime(2026, 3, 17, 4, 2, 11, tzinfo=timezone.utc)))
passwd.append("nobody:x:65534:65534:nobody:/nonexistent:/usr/sbin/nologin")
rows.append(("nobody", "", "", None))
uid = 1000
froms = ["10.0.4.17", "10.0.4.52", "bastion-01.corp.ex", "203.0.113.45", "198.51.100.7", ""]
for u, full in people:
    shell = R.choice(["/bin/bash", "/bin/bash", "/bin/zsh", "/usr/sbin/nologin"])
    passwd.append("%s:x:%d:%d:%s,,,:/home/%s:%s" % (u, uid, uid, full, u, shell))
    if u in login:
        w = login[u]
        port = "" if w is None else R.choice(["pts/0", "pts/2", "tty1", "pts/11"])
        rows.append((u, port, "" if w is None else R.choice(froms), w))
    uid += 1 + R.randint(0, 3)
rows.insert(len(rows) - 3, ("ghost", "pts/3", "10.0.4.99", datetime(2025, 12, 1, 8, 0, 3, tzinfo=timezone.utc)))

with open("etc/passwd", "w") as f:
    f.write("\n".join(passwd) + "\n")
with open("lastlog.txt", "w") as f:
    f.write("%-16s %-8s %-16s %s\n" % ("Username", "Port", "From", "Latest"))
    for name, port, frm, w in rows:
        if w is None:
            f.write("%-16s %-8.8s %-16.16s %s\n" % (name, "", "", "**Never logged in**"))
        else:
            f.write("%-16s %-8.8s %-16.16s %s\n" % (name, port, frm, fmt(w)))
PY
cksum etc/passwd lastlog.txt > .lm-state/inputs

cat > TICKET.md <<'LMEND'
# ACCESS-REVIEW Q4: dormant accounts on app-07

Reference date: 2026-11-10.

Files: etc/passwd (this server's accounts) and lastlog.txt (the output of
`lastlog` on this server).

Scope: regular accounts only, UID 1000-59999. System and service accounts are
not reviewed.

Dormant: the last login, converted to UTC, falls on or before 2026-08-12 (90
days before the reference date), or the account has never logged in. An
account that lastlog does not list at all has never logged in.

Report: dormant.txt, one line per dormant account:
    <user> <YYYY-MM-DD>      the UTC date of the last login
    <user> never
LMEND
