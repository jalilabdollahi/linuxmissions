#!/bin/bash
# The old server's etc passwd/group (old/etc), the new server's (etc), and
# restore-listing.txt (ls -ln format, owners as old numbers, paths relative to
# restored/, with spaces and an apostrophe in some names). IDs differ between
# the servers on purpose: an old UID that exists on the new host for someone
# else, groups whose numbers moved separately from users', an owner (erin) and
# a group (ftpusers) missing on the new host, and a retired old account that
# owns nothing. bin/chown is a recording stand-in.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p bin old/etc etc restored .lm-state
cp "$(dirname "$0")/chown" bin/chown
chmod +x bin/chown

python3 - "$RANDOM$$" <<'PY'
import os, random, sys
R = random.Random(int(sys.argv[1]))
old_users = [("root", 0), ("www-data", 33), ("alice", 1001), ("bob", 1002), ("carol", 1003), ("dave", 1004),
             ("erin", 1005), ("gus", 1006), ("legacy-ftp", 1007)]
old_groups = [("root", 0), ("www-data", 33), ("alice", 1001), ("bob", 1002), ("carol", 1003), ("dave", 1004),
              ("erin", 1005), ("dev", 2001), ("ops", 2002), ("finance", 2003), ("ftpusers", 2004)]
# new server: different numbers; old 1003 (carol) is dave here, old 2001 (dev) is ops here
nu = {"root": 0, "www-data": 33, "alice": 1002, "bob": 1003, "carol": 1004, "dave": 1001, "gus": 1005, "newhire": 1006}
ng = {"root": 0, "www-data": 33, "alice": 1002, "bob": 1003, "carol": 1004, "dave": 1001, "ops": 2001, "dev": 3001, "finance": 3002, "newhire": 1006}
def w(path, rows, kind):
    with open(path, "w") as f:
        for n, i in rows:
            if kind == "passwd":
                sh = "/usr/sbin/nologin" if n in ("www-data", "legacy-ftp") else "/bin/bash"
                f.write("%s:x:%d:%d:%s:/home/%s:%s\n" % (n, i, i, n.title(), n, sh))
            else:
                f.write("%s:x:%d:\n" % (n, i))
w("old/etc/passwd", old_users, "passwd"); w("old/etc/group", old_groups, "group")
w("etc/passwd", sorted(nu.items(), key=lambda x: x[1]), "passwd"); w("etc/group", sorted(ng.items(), key=lambda x: x[1]), "group")

ou = dict((i, n) for n, i in old_users); og = dict((i, n) for n, i in old_groups)
rev_u = dict(old_users); rev_g = dict(old_groups)
paths = [
    ("d", "srv"), ("d", "srv/data"), ("f", "srv/data/Q3 report.xlsx"), ("f", "srv/data/Marta's notes.txt"),
    ("f", "srv/data/budget-2026.csv"), ("f", "srv/data/raw dumps/jan.tar"), ("d", "srv/data/raw dumps"),
    ("d", "home"), ("d", "home/alice"), ("f", "home/alice/.bashrc"), ("f", "home/alice/todo list.txt"),
    ("d", "home/bob"), ("f", "home/bob/.profile"), ("d", "home/carol"), ("f", "home/carol/.ssh-config"),
    ("d", "home/dave"), ("f", "home/dave/notes.md"), ("d", "home/erin"), ("f", "home/erin/draft (final).odt"),
    ("d", "var/www"), ("f", "var/www/index.html"), ("f", "var/www/uploads/photo 01.jpg"), ("d", "var/www/uploads"),
    ("d", "srv/ftp"), ("f", "srv/ftp/inbound.log"), ("f", "srv/ftp/old orders.csv"), ("f", "etc/app.conf"), ("d", "etc"),
]
owners = {  # path prefix owner pairs (user, group), by name on the OLD server
    "srv": ("root", "root"), "srv/data": ("alice", "dev"), "home": ("root", "root"), "var/www": ("www-data", "www-data"),
    "etc": ("root", "root"), "srv/ftp": ("legacy-ftp", "ftpusers"),
}
pick = {
    "srv/data/Q3 report.xlsx": ("carol", "finance"), "srv/data/Marta's notes.txt": ("bob", "dev"),
    "srv/data/budget-2026.csv": ("carol", "finance"), "srv/data/raw dumps": ("alice", "ops"), "srv/data/raw dumps/jan.tar": ("dave", "ops"),
    "home/alice": ("alice", "alice"), "home/alice/.bashrc": ("alice", "alice"), "home/alice/todo list.txt": ("alice", "ftpusers"),
    "home/bob": ("bob", "bob"), "home/bob/.profile": ("bob", "bob"), "home/carol": ("carol", "carol"), "home/carol/.ssh-config": ("carol", "carol"),
    "home/dave": ("dave", "dave"), "home/dave/notes.md": ("dave", "dev"), "home/erin": ("erin", "erin"),
    "home/erin/draft (final).odt": ("erin", "dev"), "var/www/index.html": ("www-data", "dev"), "var/www/uploads": ("www-data", "www-data"),
    "var/www/uploads/photo 01.jpg": ("www-data", "www-data"), "srv/ftp/inbound.log": ("legacy-ftp", "ftpusers"),
    "srv/ftp/old orders.csv": ("legacy-ftp", "finance"), "etc/app.conf": ("root", "ops"),
}
rows = []
for kind, p in paths:
    u, g = pick.get(p) or owners.get(p) or ("root", "root")
    mode = "drwxr-xr-x" if kind == "d" else R.choice(["-rw-r--r--", "-rw-rw----", "-rw-------", "-rwxr-xr-x"])
    size = 4096 if kind == "d" else R.randint(120, 90000)
    day = R.randint(1, 28)
    rows.append((p, "%s %d %d %d %5d 2026-10-%02d %02d:%02d %s" % (mode, 2 if kind == "d" else 1, rev_u[u], rev_g[g], size, day, R.randint(0, 23), R.randint(0, 59), p)))
rows.sort(key=lambda r: r[0])
with open("restore-listing.txt", "w") as f:
    for _, line in rows:
        f.write(line + "\n")
for kind, p in paths:
    full = os.path.join("restored", p)
    if kind == "d":
        os.makedirs(full, exist_ok=True)
for kind, p in paths:
    full = os.path.join("restored", p)
    if kind == "f":
        os.makedirs(os.path.dirname(full), exist_ok=True)
        open(full, "w").close()
PY
mkdir -p .lm-state/in && cp old/etc/passwd .lm-state/in/old-passwd && cp old/etc/group .lm-state/in/old-group && cp etc/passwd .lm-state/in/new-passwd && cp etc/group .lm-state/in/new-group && cp restore-listing.txt .lm-state/in/listing
: > .lm-state/chown.log

cat > TICKET.md <<'LMEND'
# OPS-4410: wrong owners after the app-09 restore

The files in restored/ came back with the OLD server's numeric IDs. On app-09
the same numbers belong to different people, so we map by NAME.

  old/etc/passwd, old/etc/group   the old server's account databases
  etc/passwd, etc/group           app-09's
  restore-listing.txt             ls -ln style listing of restored/ (old IDs,
                                  paths relative to restored/)

Deliverables:
  chown-plan.sh   one chown per path, run from inside restored/:
                    both names exist on app-09     chown user:group 'path'
                    only the user exists           chown user 'path'
                    only the group exists          chown :group 'path'
                    neither exists                 no line for that path
                  Quote every path (spaces, apostrophes).
  unmapped.txt    each owner seen in the listing that does not exist on
                  app-09, once: "user NAME" or "group NAME".

bin/chown is a recording stand-in (this sandbox is not root): run your plan
with it, then look at what it recorded in .lm-state/chown.log.
LMEND
