#!/bin/bash
# On a cp -a copy of deploy/ in another directory: every link resolves inside
# the copy; current, bin/app, shared/uploads, logs and config/active.conf point
# where NOTES.md says; active.conf follows both an in-place append and a
# replace-style edit of releases/<new>/app.conf; the old release is unchanged.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
[ -s .lm-state/truth.json ] || { echo "❌ the level's data is gone; type 'reset'"; exit 1; }
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/other/place"
cp -a deploy "$TMP/other/place/" 2>/dev/null
python3 - "$TMP/other/place/deploy" <<'PY'
import hashlib, json, os, sys
copy = os.path.realpath(sys.argv[1])
t = json.load(open(".lm-state/truth.json"))
new, old = t["new"], t["old"]
for r, ds, fs in os.walk(copy):
    for n in ds + fs:
        p = os.path.join(r, n)
        if os.path.islink(p):
            rel = os.path.relpath(p, copy)
            try:
                real = os.path.realpath(p, strict=True)
            except OSError as e:
                kind = "loops" if "symbolic" in str(e).lower() or getattr(e, "errno", 0) == 40 else "is dangling"
                print("❌ deploy/%s %s (checked on a moved copy of the tree)" % (rel, kind)); sys.exit(1)
            if not (real == copy or real.startswith(copy + os.sep)):
                print("❌ deploy/%s points outside the tree, so it breaks when deploy/ is moved (use a relative target)" % rel); sys.exit(1)
def target(rel): return os.path.realpath(os.path.join(copy, rel))
want = {"current": "releases/" + new, "bin/app": "releases/%s/bin/app" % new, "shared/uploads": "storage/uploads", "logs": "storage/logs", "config/active.conf": "releases/%s/app.conf" % new}
for rel, w in want.items():
    p = os.path.join(copy, rel)
    if rel != "config/active.conf" and not os.path.islink(p):
        print("❌ deploy/%s is not a link any more" % rel); sys.exit(1)
    if target(rel) != os.path.realpath(os.path.join(copy, w)):
        print("❌ deploy/%s resolves to %s, expected deploy/%s" % (rel, os.path.relpath(target(rel), copy), w)); sys.exit(1)
if not os.path.islink(os.path.join(copy, "config/active.conf")):
    print("❌ deploy/config/active.conf is a regular file (or a hard link): it cannot follow every kind of edit of releases/%s/app.conf" % new); sys.exit(1)
if not os.path.exists(os.path.join(copy, "shared/uploads/report.csv")):
    print("❌ deploy/shared/uploads does not show the uploaded files"); sys.exit(1)
conf = os.path.join(copy, "releases/%s/app.conf" % new)
with open(conf, "a") as f: f.write("# appended-in-place\n")
act = os.path.join(copy, "config/active.conf")
if "# appended-in-place" not in open(act).read():
    print("❌ active.conf does not show a line appended to releases/%s/app.conf" % new); sys.exit(1)
txt = open(conf).read().replace("workers", "WORKERS")
tmp = conf + ".tmp"; open(tmp, "w").write(txt); os.replace(tmp, conf)
if "WORKERS" not in open(act).read():
    print("❌ active.conf stopped following releases/%s/app.conf after the file was rewritten by an editor (a hard link stays with the old inode)" % new); sys.exit(1)
oc = "deploy/releases/%s/app.conf" % old
if not os.path.isfile(oc) or hashlib.sha256(open(oc, "rb").read()).hexdigest() != t["old_sha"]:
    print("❌ the old release's app.conf was changed; it must stay as it was"); sys.exit(1)
if not os.path.isdir("deploy/releases/" + new) or os.path.exists("deploy/releases/v%s" % new.split(".")[0]):
    print("❌ the release folder names must stay as they are now"); sys.exit(1)
PY
[ $? -eq 0 ] || exit 1
echo "✅ no broken or looping links, nothing absolute, active.conf follows the new config, and the tree works after being moved"
