#!/bin/bash
# Builds a fixture cache (old/new files, .keep, odd names, symlinks out), runs
# cleanup.sh against it and against four bad CACHE_DIR values from a decoy cwd.
SANDBOX="$(cd "$1" && pwd)"
cd "$SANDBOX" || exit 1

if [ ! -f cleanup.sh ]; then
  echo "❌ cleanup.sh is missing (type reset to get it back)"
  exit 1
fi
sum=$(sha256sum cleanup.sh 2>/dev/null || shasum -a 256 cleanup.sh)
if [ "${sum%% *}" = "$(cat .lm/orig.sha 2>/dev/null)" ]; then
  echo "❌ cleanup.sh is unchanged: it still deletes the wrong things when CACHE_DIR is unset"
  exit 1
fi
if [ ! -x cleanup.sh ]; then
  echo "❌ cleanup.sh is not executable any more; cron runs it by its path"
  exit 1
fi

python3 - "$SANDBOX" <<'PY'
import os
import shutil
import subprocess
import sys
import tempfile
import time

sandbox = sys.argv[1]
script = os.path.join(sandbox, "cleanup.sh")
root = tempfile.mkdtemp(prefix=".lm-check.", dir=sandbox)
DAY = 86400
now = time.time()


def mk(rel, age_days, base=root, data="x\n"):
    p = os.path.join(base, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, "w") as f:
        f.write(data)
    os.utime(p, (now - age_days * DAY, now - age_days * DAY))
    return p


def link(rel, target, age_days, base=root):
    p = os.path.join(base, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    os.symlink(target, p)
    os.utime(p, (now - age_days * DAY, now - age_days * DAY), follow_symlinks=False)


def snapshot(*dirs):
    out = []
    for d in dirs:
        for dp, dn, fn in os.walk(d):
            for n in dn + fn:
                out.append(os.path.join(dp, n))
    return sorted(out)


cache = os.path.join(root, "cache")
os.makedirs(cache)
# kept: new files, .keep everywhere, directories, symlinks
for rel, age in [("fresh.dat", 2), ("recent.log", 6), (".keep", 400), ("sessions/.keep", 400),
                 ("sessions/s-new", 1), ("deep/a/b/new.dat", 3)]:
    mk(rel, age, cache)
# deleted: regular files older than 7 days, whatever their name
gone = ["old-9.tmp", "old-30.tmp", "sessions/s-old", "sessions/.keep.bak", ".index",
        "old report v2.tmp", "bad\nname.tmp", "-rf", "deep/a/b/old.dat", "deep/a/old.dat"]
for rel in gone:
    mk(rel, 12 if rel[0] in "ob-" else 40, cache)
os.makedirs(os.path.join(cache, "emptydir"))
os.utime(os.path.join(cache, "emptydir"), (now - 100 * DAY, now - 100 * DAY))
outside = os.path.join(root, "outside")
mk("secret.old", 500, outside)
mk("dir/old.dat", 500, outside)
mk("dir/.keep", 500, outside)
link("link-out", "../outside/secret.old", 60, cache)
link("linkdir", "../outside/dir", 60, cache)
link("link-in", "fresh.dat", 20, cache)
link("broken-link", "nowhere", 20, cache)
decoy = os.path.join(root, "decoy")
mk("old-in-cwd", 100, decoy)
mk("uploads/photo.jpg", 100, decoy)
mk("uploads/.keep", 100, decoy)
os.makedirs(os.path.join(decoy, "uploads/empty"))
notdir = mk("plain-file", 100, root)


def run(env_extra, unset=False):
    env = {k: v for k, v in os.environ.items() if k != "CACHE_DIR"}
    env["PATH"] = "/usr/bin:/bin"
    env.update(env_extra)
    return subprocess.run([script], cwd=decoy, env=env, stdin=subprocess.DEVNULL,
                          capture_output=True, text=True, timeout=20)


def fail(msg):
    shutil.rmtree(root, ignore_errors=True)
    print(msg)
    sys.exit(1)


bad = [("unset", {}), ("empty", {"CACHE_DIR": ""}),
       ("pointing at a file", {"CACHE_DIR": notdir}),
       ("pointing at a missing path", {"CACHE_DIR": os.path.join(root, "nope")})]
for label, env in bad:
    before = snapshot(root)
    try:
        r = run(env)
    except subprocess.TimeoutExpired:
        fail(f"❌ cleanup.sh hung when CACHE_DIR was {label}")
    if snapshot(root) != before:
        fail(f"❌ with CACHE_DIR {label}, cleanup.sh still deleted files; it must delete nothing then")
    if r.returncode == 0:
        fail(f"❌ with CACHE_DIR {label}, cleanup.sh exited 0; it must refuse with a non-zero status")
    if not r.stderr.strip():
        fail(f"❌ with CACHE_DIR {label}, cleanup.sh failed silently; print the reason on stderr")

before = set(snapshot(root))
try:
    r = run({"CACHE_DIR": cache})
except subprocess.TimeoutExpired:
    fail("❌ cleanup.sh hung on a good cache directory")
if r.returncode != 0:
    fail(f"❌ cleanup.sh failed on a valid cache directory (exit {r.returncode}): {(r.stderr.strip().splitlines() or [''])[0][:80]}")
after = set(snapshot(root))
want_gone = {os.path.join(cache, g) for g in gone}
still_there = sorted(p for p in want_gone if p in after)
if still_there:
    n = os.path.relpath(still_there[0], cache).replace("\n", "\\n")
    fail(f"❌ {len(still_there)} old file(s) are still in the cache, e.g. '{n}'")
removed = sorted(before - after - want_gone)
if removed:
    n = os.path.relpath(removed[0], root).replace("\n", "\\n")
    fail(f"❌ cleanup.sh also removed something it must keep: {n}")
if not os.path.isfile(os.path.join(outside, "secret.old")) or not os.path.isfile(os.path.join(outside, "dir", "old.dat")):
    fail("❌ cleanup.sh reached through a symlink and deleted a file outside the cache")
shutil.rmtree(root, ignore_errors=True)
print("✅ cleanup.sh deletes only old regular files in a valid cache and refuses everything else")
PY
exit $?
