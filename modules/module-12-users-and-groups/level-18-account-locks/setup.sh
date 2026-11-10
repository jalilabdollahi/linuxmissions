#!/bin/bash
# app-02's etc/passwd + etc/shadow (shared mock usermod/passwd/chage/getent in
# bin/). HR's ticket names four leavers by full name and email. The staff pool
# is shuffled: for each leaver the username does not look like the name; one
# leaver's email is in GECOS, one only matches by full name (and a look-alike
# colleague shares the first part of that name), one is already locked, and
# the shared deploy account carries a leaver's email in its comment and is
# listed as "do not touch".
SANDBOX="$1"
cd "$SANDBOX" || exit 1
M="$(dirname "$0")/../../../mocks"
mkdir -p bin etc .lm .lm-state
for t in usermod passwd chage getent; do cp "$M/accounts/$t" bin/; done
echo "2026-11-10" > .lm/now

python3 - "$RANDOM$$" <<'PY'
import random, string, sys
R = random.Random(int(sys.argv[1]))

def h():
    chars = string.ascii_letters + string.digits + "./"
    return "$y$j9T$" + "".join(R.choice(chars) for _ in range(22)) + "$" + "".join(R.choice(chars) for _ in range(43))

# username, full name, company email
staff = [("kowalski", "Ida Kowalska", "ida.kowalska@corp.example"), ("tbecker", "Tom Becker", "tom.becker@corp.example"),
         ("mrivera", "Marta Rivera", "marta.rivera@corp.example"), ("jpark", "Jin Park", "jin.park@corp.example"),
         ("nsingh", "Neha Singh", "neha.singh@corp.example"), ("lfischer", "Lukas Fischer", "lukas.fischer@corp.example"),
         ("aokafor", "Adaeze Okafor", "adaeze.okafor@corp.example"), ("dvega", "Diego Vega", "diego.vega@corp.example"),
         ("hsato", "Hana Sato", "hana.sato@corp.example"), ("cmoreau", "Camille Moreau", "camille.moreau@corp.example")]
R.shuffle(staff)
leavers = staff[:4]
keep = staff[4:]
# shuffle usernames so they are not guessable from the names
uid = 1001
# the colleague whose name starts like the full-name-only leaver's
l_email, l_pre, l_locked, l_full = leavers[0], leavers[1], leavers[2], leavers[3]
twin_first = l_full[1].split()[0]
twin = ("%s.lt" % twin_first.lower()[:4], "%s %s-Lindqvist" % (twin_first, l_full[1].split()[1]), "%s.%s-lindqvist@corp.example" % (twin_first.lower(), l_full[1].split()[1].lower()))
everyone = [(l_email, "email"), (l_pre, "email"), (l_locked, "email"), (l_full, "name")] + [(k, "keep") for k in keep] + [(twin, "twin")]
R.shuffle(everyone)

passwd = ["root:x:0:0:root:/root:/bin/bash", "daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin",
          "sshd:x:105:65534::/run/sshd:/usr/sbin/nologin"]
shadow = ["root:$y$j9T$rootrootrootrootroot$AbCdEfGhIjKlMnOpQrStUvWxYz0123456789AbCdEfG:20400:0:99999:7:::",
          "daemon:*:20123:0:99999:7:::", "sshd:*:20123:0:99999:7:::"]
want = []
ticket_lines = []
for (u, full, mail), kind in everyone:
    uid += R.randint(1, 3)
    if kind == "name":
        gecos = "%s,Room %d,x%d" % (full, R.randint(1, 9), R.randint(2000, 2999))
    elif kind == "twin":
        gecos = "%s,Room %d,x%d,%s" % (full, R.randint(1, 9), R.randint(2000, 2999), mail)
    else:
        gecos = "%s,Room %d,x%d,%s" % (full, R.randint(1, 9), R.randint(2000, 2999), mail)
    passwd.append("%s:x:%d:%d:%s:/home/%s:/bin/bash" % (u, uid, uid, gecos, u))
    day = R.randint(19800, 20400)
    pw = h()
    exp = ""
    if kind == "email" and (u, full, mail) == l_locked:
        pw = "!" + pw
    if kind == "keep" and R.random() < 0.3:
        pw = "!" + pw
    if kind == "keep" and R.random() < 0.3:
        exp = str(R.randint(21000, 21500))
    shadow.append("%s:%s:%d:0:99999:7::%s:" % (u, pw, day, exp))
    if kind in ("email", "name"):
        want.append(u)
# the shared deploy account: its comment mentions the first leaver's email
uid += 7
passwd.append("deploy:x:%d:%d:Shared deploy account (owner: %s),,,:/home/deploy:/bin/bash" % (uid, uid, l_email[2]))
shadow.append("deploy:%s:20250:0:99999:7:::" % h())
passwd.append("backup:x:34:34:backup:/var/backups:/usr/sbin/nologin")
shadow.append("backup:*:20123:0:99999:7:::")

open("etc/passwd", "w").write("\n".join(passwd) + "\n")
open("etc/shadow", "w").write("\n".join(shadow) + "\n")
group = ["root:x:0:", "deploy:x:%d:" % uid]
open("etc/group", "w").write("\n".join(group) + "\n")
open(".lm-state/leavers", "w").write("\n".join(want) + "\n")

# HR ticket: names and emails only, in a different order
order = list(leavers)
R.shuffle(order)
t = ["# HR-8841: leavers, last day 2026-11-10", "",
     "Please disable access for the following people today (last day: 2026-11-10).",
     "The directory only gives us names and company email; we do not know their",
     "server usernames.", ""]
for (u, full, mail) in order:
    if (u, full, mail) == l_full:
        t.append("  - %s (email: %s)" % (full, mail))
    else:
        t.append("  - %s <%s>" % (full, mail))
t += ["", "Disable means: password locked and the account expired as of today.",
      "Do not remove the accounts or their home directories (legal hold).", "",
      "Do NOT touch the shared 'deploy' account: it appears in our directory with",
      "%s as its owner's address, but it must keep working." % l_email[2], ""]
open("TICKET.md", "w").write("\n".join(t))
PY
cp etc/passwd .lm-state/passwd.orig
cp etc/shadow .lm-state/shadow.orig
