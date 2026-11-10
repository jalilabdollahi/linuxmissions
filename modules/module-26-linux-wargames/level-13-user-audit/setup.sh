#!/bin/bash
# Three people left. A captured sysroot/ (passwd, shadow, group, authorized_keys
# files) with: a departed person's key in the shared deploy account under
# another comment, a look-alike comment on a current user's different key, a
# key with options, and a UID-0 account with an ordinary name.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
MOCKS="$(cd "$(dirname "$0")/../../../mocks" && pwd)"
mkdir -p sysroot/bin sysroot/etc departed .lm-state
for t in usermod userdel getent passwd; do cp "$MOCKS/accounts/$t" sysroot/bin/; done
python3 - <<'PY'
import base64, hashlib, json, os, random
R = random.Random()
AL = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
def body(): return "AAAAC3NzaC1lZDI1NTE5AAAAI" + "".join(R.choice(AL) for _ in range(43))
people = R.sample(["alice", "bob", "carol", "dmitri", "eva", "farid", "gita", "hamid", "ines", "jonas"], 8)
gone, stay = people[:3], people[3:]
backdoor = R.choice(["sysbackup", "cups-helper", "dbus-sync"])
users = [("root", 0, 0, "/root", "/bin/bash"), ("daemon", 1, 1, "/usr/sbin", "/usr/sbin/nologin"), ("www-data", 33, 33, "/var/www", "/usr/sbin/nologin")]
uid = 1000
for p in people + ["deploy"]:
    users.append((p, uid, uid, "/home/" + p, "/bin/bash")); uid += 1
users.insert(4, (backdoor, 0, 0, "/var/lib/" + backdoor, "/bin/bash"))
pw = ["%s:x:%d:%d:%s:%s:%s" % (n, u, g, n.title() if n in people else n, h, s) for n, u, g, h, s in users]
sh = []
for n, u, g, h, s in users:
    if "nologin" in s: sh.append("%s:*:19800:0:99999:7:::" % n)
    else: sh.append("%s:$6$%s$%s:%d:0:99999:7:::" % (n, "".join(R.choice(AL) for _ in range(8)), "".join(R.choice(AL) for _ in range(40)), R.randint(19500, 20400)))
grp = ["root:x:0:", "daemon:x:1:", "adm:x:4:%s,%s" % (backdoor, stay[0]), "sudo:x:27:%s,%s,%s" % (stay[0], backdoor, gone[0]), "www-data:x:33:"]
uid = 1000
for p in people + ["deploy"]:
    grp.append("%s:x:%d:" % (p, uid)); uid += 1
grp.append("ops:x:2000:%s,%s,%s" % (stay[1], gone[1], backdoor))
keys = {p: body() for p in people}
keys["deploy-ci"] = body(); keys[backdoor] = body()
decoy = body()   # current user's key, comment mentions a departed person
ak = {}
def line(b, c, opts=""): return (opts + " " if opts else "") + "ssh-ed25519 %s %s" % (b, c)
for p in people:
    ak["home/%s/.ssh/authorized_keys" % p] = ["# keys for " + p, line(keys[p], p + "@laptop")]
ak["home/deploy/.ssh/authorized_keys"] = [
    line(keys["deploy-ci"], "ci-runner"),
    line(keys[gone[0]], "backup-2025"),
    line(keys[stay[0]], stay[0] + "@ops"),
    line(keys[gone[1]], gone[1] + "@laptop", 'command="/usr/bin/rsync --server --sender",no-pty'),
]
ak["root/.ssh/authorized_keys"] = [line(keys[stay[1]], "break-glass"), line(keys[gone[2]], "old-admin")]
ak["home/%s/.ssh/authorized_keys" % stay[2]].append(line(decoy, gone[0] + ".work (contractor, still active)"))
ak["var/lib/%s/.ssh/authorized_keys" % backdoor] = [line(keys[backdoor], "maintenance")]
sr = "sysroot/"
os.makedirs(sr + "etc", exist_ok=True)
open(sr + "etc/passwd", "w").write("\n".join(pw) + "\n")
open(sr + "etc/shadow", "w").write("\n".join(sh) + "\n"); os.chmod(sr + "etc/shadow", 0o640)
open(sr + "etc/group", "w").write("\n".join(grp) + "\n")
for p, ls in ak.items():
    os.makedirs(os.path.dirname(sr + p), exist_ok=True)
    open(sr + p, "w").write("\n".join(ls) + "\n")
for g in gone:
    open("departed/%s.pub" % g, "w").write(line(keys[g], g + "@laptop") + "\n")
# truth
exp_pw = [l for l in pw if not l.startswith(backdoor + ":")]
exp_grp = []
for l in grp:
    n, x, gid, mem = l.split(":")
    mem = [m for m in mem.split(",") if m and m != backdoor]
    exp_grp.append("%s:%s:%s:%s" % (n, x, gid, ",".join(mem)))
audit = ["locked " + g for g in gone] + ["uid0 " + backdoor]
exp_ak = {}
for p, ls in ak.items():
    kept = []
    for l in ls:
        tok = l.split(); b = tok[tok.index("ssh-ed25519") + 1] if "ssh-ed25519" in tok else None
        who = [g for g in gone if keys[g] == b]
        if who: audit.append("key %s %s" % (p, who[0]))
        else: kept.append(l)
    exp_ak[p] = kept
json.dump({"gone": gone, "backdoor": backdoor, "passwd": exp_pw, "group": exp_grp, "shadow_orig": sh, "audit": sorted(audit), "ak": exp_ak, "bodies": [keys[g] for g in gone]}, open(".lm-state/truth.json", "w"))
open("OFFBOARD.md", "w").write("""# Offboarding audit

HR confirms that %s, %s and %s left last month. Their old public keys
are in `departed/` (the comment on a key can be anything; the key body is what
counts).

The captured server state is in `sysroot/` (etc/passwd, etc/shadow, etc/group and
every account's .ssh/authorized_keys). The usual account tools are in
`sysroot/bin/` and edit that tree, not your real system.

Required end state:
- the three accounts are locked (password field in shadow), nothing else about them changes;
- none of their keys remains in any authorized_keys under sysroot/, including shared accounts;
- any account that has UID 0 without being root is removed (it was not created by us);
- `audit.txt` lists the findings, one per line, sorted, in exactly these forms:
      locked LOGIN
      key PATH-RELATIVE-TO-SYSROOT LOGIN-OF-THE-DEPARTED-PERSON   (one per removed key line)
      uid0 LOGIN
Do not touch anything else: current users must keep working.
""" % tuple(gone))
PY
