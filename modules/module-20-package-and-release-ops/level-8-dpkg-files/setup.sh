#!/bin/bash
# Who Owns This File: a merged-/usr root (/bin, /sbin, /lib are symlinks into
# /usr). Six random suspects: two reached through those symlinks, two plainly
# owned, two that no package owns (hand-installed and generated at runtime).
SANDBOX="$1"
cd "$SANDBOX" || exit 1
MOCKS="$(cd "$(dirname "$0")/../../../mocks" && pwd)"
mkdir -p "$SANDBOX/.lm"
python3 - "$SANDBOX" "$MOCKS" <<'PY' || exit 1
import random, sys
sandbox, mocks = sys.argv[1:3]
sys.path.insert(0, mocks + "/packages")
import pkgsim

r = random.Random()
tools = r.sample(["dbtool", "logship", "mailq-lite", "pingx", "fswatch", "hashcheck", "tarsnap-lite", "netprobe",
                  "diskwarn", "cronmon", "certwatch", "queuectl"], 10)
def pk(t):
    return {"name": t, "version": "1.%d-1" % r.randint(0, 9), "description": f"{t} tool",
            "files": {f"/usr/bin/{t}": {"content": "#!/bin/sh\n", "mode": "0755"},
                      f"/usr/sbin/{t}d": {"content": "#!/bin/sh\n", "mode": "0755"},
                      f"/usr/lib/{t}/helper.so": "so\n",
                      f"/etc/{t}/{t}.conf": f"# {t} settings\n",
                      f"/usr/share/doc/{t}/copyright": "License: MIT\n"}}
fx = {"links": {"/bin": "usr/bin", "/sbin": "usr/sbin", "/lib": "usr/lib"},
      "repos": [{"name": "ubuntu", "suite": "noble", "origin": "Ubuntu", "packages": [pk(t) for t in tools]}],
      "installed": list(tools), "files": {}}
t = iter(tools)
rows = []
a, b = next(t), next(t)
rows.append((r.choice([f"/bin/{a}", f"/sbin/{a}d"]), a))
rows.append((r.choice([f"/lib/{b}/helper.so", f"/bin/{b}"]), b))
c, d = next(t), next(t)
rows.append((r.choice([f"/etc/{c}/{c}.conf", f"/usr/share/doc/{c}/copyright"]), c))
rows.append((r.choice([f"/usr/bin/{d}", f"/usr/lib/{d}/helper.so"]), d))
e, f = next(t), next(t)
p = r.choice([f"/usr/local/bin/{e}-wrapper", f"/opt/{e}/bin/{e}"])
fx["files"][p] = {"content": "#!/bin/sh\n", "mode": "0755"}
rows.append((p, "none"))
p = r.choice([f"/etc/{f}/generated.conf", f"/var/lib/{f}/state.db"])
fx["files"][p] = "written by a script\n"
rows.append((p, "none"))
r.shuffle(rows)
try:
    pkgsim.build(sandbox, fx)
except pkgsim.FixtureError as e:
    print(e); sys.exit(1)
open(sandbox + "/suspects.txt", "w").write("".join(p + "\n" for p, _ in rows))
open(sandbox + "/.lm/expected.tsv", "w").write("".join(f"{p}\t{o}\n" for p, o in rows))
PY
