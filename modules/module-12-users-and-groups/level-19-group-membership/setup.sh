#!/bin/bash
# build-05: etc/passwd, etc/group, etc/gshadow and changes.csv (action,user,group).
# The shared mock gpasswd edits group and gshadow together. The CSV has
# duplicates, adds of existing members, removes of non-members, a user added
# and then removed again, and removals that empty a group's member list.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
M="$(dirname "$0")/../../../mocks"
mkdir -p bin etc .lm-state
for t in gpasswd getent groups id; do cp "$M/accounts/$t" bin/; done

python3 - "$RANDOM$$" <<'PY'
import random, sys
R = random.Random(int(sys.argv[1]))
users = ["anya", "marco", "tkaur", "lwong", "jbrooks", "fatima", "rsato", "mdiaz", "pnovak", "ychen"]
R.shuffle(users)
u = users
passwd = ["root:x:0:0:root:/root:/bin/bash", "daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin"]
for i, name in enumerate(users):
    passwd.append("%s:x:%d:%d:%s:/home/%s:/bin/bash" % (name, 1001 + i, 1001 + i, name.title(), name))
open("etc/passwd", "w").write("\n".join(passwd) + "\n")

# groups with members; 'ops' has a single member, 'oncall' has two, 'deploy' none
groups = [("root", 0, []), ("sudo", 27, [u[0]]), ("docker", 999, [u[0], u[1], u[2]]), ("developers", 2001, [u[1], u[3], u[4]]),
          ("qa", 2002, [u[5]]), ("ops", 2003, [u[6]]), ("oncall", 2004, [u[0], u[2]]), ("deploy", 2005, [])]
admins = {"developers": [u[1]], "ops": [u[0]]}
with open("etc/group", "w") as g, open("etc/gshadow", "w") as s:
    for name, gid, mem in groups:
        g.write("%s:x:%d:%s\n" % (name, gid, ",".join(mem)))
        pw = "!"
        s.write("%s:%s:%s:%s\n" % (name, pw, ",".join(admins.get(name, [])), ",".join(mem)))

rows = [
    ("add", u[7], "developers"), ("remove", u[3], "developers"), ("add", u[2], "docker"),
    ("remove", u[6], "ops"), ("add", u[8], "ops"), ("add", u[8], "docker"), ("add", u[8], "ops"),
    ("remove", u[5], "qa"), ("add", u[9], "qa"), ("add", u[9], "deploy"), ("remove", u[9], "deploy"),
    ("remove", u[4], "qa"), ("remove", u[0], "oncall"), ("remove", u[2], "oncall"), ("add", u[3], "deploy"),
    ("remove", u[1], "docker"), ("add", u[7], "docker"),
]
with open("changes.csv", "w") as f:
    f.write("action,user,group\n")
    for a, usr, grp in rows:
        f.write("%s,%s,%s\n" % (a, usr, grp))
PY
cp etc/group .lm-state/group.orig
cp etc/gshadow .lm-state/gshadow.orig
cp changes.csv .lm-state/changes.orig
