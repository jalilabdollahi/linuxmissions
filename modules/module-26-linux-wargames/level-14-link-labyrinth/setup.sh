#!/bin/bash
# After renaming release folders v<N> -> <N>.0: dangling relative links, a
# two-link loop, an absolute link that breaks when the tree moves, and
# config/active.conf as a hard link to the OLD release's file (it "works" but
# never follows edits and writes through it damage the old release).
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state
python3 - "$SANDBOX" <<'PY'
import hashlib, json, os, random, sys
SB = sys.argv[1]
R = random.Random()
new = R.randint(3, 7); old = new - 1
newv = "%d.0" % new; oldv = "%d.%d" % (old, R.randint(0, 9))
def w(p, t, mode=None):
    os.makedirs(os.path.dirname(p), exist_ok=True); open(p, "w").write(t)
    if mode: os.chmod(p, mode)
port_old, port_new = R.randint(8000, 8400), R.randint(8500, 8999)
w("deploy/releases/%s/app.conf" % oldv, "# release %s\nlisten = %d\nworkers = %d\n" % (oldv, port_old, R.randint(2, 6)))
w("deploy/releases/%s/app.conf" % newv, "# release %s\nlisten = %d\nworkers = %d\nfeature_x = on\n" % (newv, port_new, R.randint(8, 16)))
for v in (oldv, newv): w("deploy/releases/%s/bin/app" % v, "#!/bin/sh\necho app %s\n" % v, 0o755)
w("deploy/storage/uploads/report.csv", "id,size\n1,10\n2,20\n")
w("deploy/storage/logs/app.log", "started\n")
os.makedirs("deploy/bin"); os.makedirs("deploy/config"); os.makedirs("deploy/shared")
os.symlink("releases/v%d" % new, "deploy/current")
os.symlink("../releases/v%d/bin/app" % new, "deploy/bin/app")
os.link("deploy/releases/%s/app.conf" % oldv, "deploy/config/active.conf")
os.symlink("uploads.current", "deploy/shared/uploads")
os.symlink("uploads", "deploy/shared/uploads.current")
os.symlink(SB + "/deploy/storage/logs", "deploy/logs")
h = hashlib.sha256(open("deploy/releases/%s/app.conf" % oldv, "rb").read()).hexdigest()
json.dump({"new": newv, "old": oldv, "old_sha": h}, open(".lm-state/truth.json", "w"))
open("NOTES.md", "w").write("""# deploy/ after the folder renames

Last week the release folders were renamed (v%d -> %s). Since then:
`./deploy/bin/app` does not start, `ls deploy/shared/uploads` says
"Too many levels of symbolic links", and the app still reads an old
config although `deploy/releases/%s/app.conf` was edited.

What the layout is supposed to be:
- `deploy/current` -> the %s release
- `deploy/bin/app` -> that release's `bin/app`
- `deploy/config/active.conf` always shows `releases/%s/app.conf`, whatever
  tool edited that file
- `deploy/shared/uploads` leads to the real directory `deploy/storage/uploads`
- `deploy/logs` leads to `deploy/storage/logs`
- the whole `deploy/` tree gets rsynced to a new server next week: every link
  must still work there (the path will not be the same)
Do not rename the release folders back, and do not change the old release.
""" % (new, newv, newv, newv, newv))
PY
