#!/bin/bash
# current resolves to the newest clean release; no stray links inside releases;
# all releases and their shared links intact; appctl reloaded after the switch.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
[ -s .lm-state/truth.json ] || { echo "❌ the level's data is gone; type 'reset'"; exit 1; }
python3 - <<'PY'
import json, os, sys
t = json.load(open(".lm-state/truth.json"))
target = t["target"]
for v in t["versions"]:
    d = "releases/" + v
    if not os.path.isdir(d):
        print("❌ release %s is gone; roll back by switching the link, do not delete releases" % v); sys.exit(1)
    sh = d + "/shared"
    if not os.path.islink(sh) or os.readlink(sh) != "../../shared" or not os.path.isfile(sh + "/config.env"):
        print("❌ the shared link inside %s is broken or missing" % d); sys.exit(1)
    for e in os.listdir(d):
        if e not in ("app.bin", "health.log", "shared"):
            print("❌ unexpected entry %s/%s (a link created inside a release, instead of replacing `current`?)" % (d, e)); sys.exit(1)
if not os.path.islink("current"):
    print("❌ current is not a symlink any more"); sys.exit(1)
real = os.path.realpath("current")
if real != os.path.realpath("releases/" + target):
    got = os.path.basename(real)
    if os.path.isdir(real) and os.path.dirname(real) == os.path.realpath("releases"):
        print("❌ current serves %s, which is not the newest release without failures in its health log" % got)
    else:
        print("❌ current points at %s, which is not a release" % os.readlink("current"))
    sys.exit(1)
lines = [l.split() for l in open(".lm-state/appctl.log") if l.strip()]
if not lines:
    print("❌ the app server was never told: run ./appctl reload after switching"); sys.exit(1)
if lines[-1][2] != "release=" + target:
    print("❌ the last reload served %s: reload after the switch, not before" % lines[-1][2].split("=")[1]); sys.exit(1)
PY
[ $? -eq 0 ] || exit 1
echo "✅ current serves the newest clean release, shared links intact, and the app server was reloaded after the switch"
