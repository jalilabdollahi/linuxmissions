#!/bin/bash
# Run the player's build.sh twice (time and source mtimes changed in between), then check
# the archive's members against the spec with python's tarfile.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
ART=dist/agent-1.4.2.tar.gz
if [ ! -f build.sh ]; then
  echo "❌ build.sh does not exist yet"
  exit 1
fi
rm -rf dist
if ! timeout 25 bash build.sh >.lm/build1.log 2>&1; then
  echo "❌ build.sh failed: $(tail -1 .lm/build1.log | cut -c1-120)"
  exit 1
fi
if [ ! -f "$ART" ]; then
  echo "❌ build.sh ran but dist/agent-1.4.2.tar.gz was not created"
  exit 1
fi
cp "$ART" .lm/build1.tgz
python3 - "$ART" .lm/files.sha256 <<'PY' || exit 1
import gzip, hashlib, struct, sys, tarfile
art, man = sys.argv[1:3]
def bad(msg):
    print("❌ " + msg); sys.exit(1)
raw = open(art, "rb").read()
if raw[:2] != b"\x1f\x8b":
    bad("dist/agent-1.4.2.tar.gz is not gzip-compressed")
flags, mtime = raw[3], struct.unpack("<I", raw[4:8])[0]
if mtime != 0:
    bad("the gzip header of the archive stores a timestamp (compress with gzip -n)")
if flags & 8:
    bad("the gzip header of the archive stores the original file name (compress with gzip -n)")
want = {}
for line in open(man):
    h, p = line.rstrip("\n").split("  ", 1)
    want[p] = h
try:
    tf = tarfile.open(art, "r:gz")
    members = tf.getmembers()
except Exception as e:
    bad(f"the archive cannot be read as a tar.gz: {e}")
names = [m.name.rstrip("/") for m in members]
if len(set(names)) != len(names):
    bad("some paths are in the archive twice (a directory listed and also archived recursively?)")
top = "agent-1.4.2"
for n in names:
    if n != top and not n.startswith(top + "/"):
        bad(f"'{n}' is outside the top directory {top}/")
if top not in names:
    bad(f"the archive has no {top}/ directory entry")
for n in names:
    base = n.rsplit("/", 1)[-1]
    if base == ".DS_Store" or base.endswith(".o") or base.endswith("~"):
        bad(f"build junk is still in the archive: {n}")
seen = {}
for m in members:
    n = m.name.rstrip("/")
    rel = n[len(top) + 1:]
    if m.isdir():
        exp = 0o755
    elif rel.startswith("bin/"):
        exp = 0o755
    elif rel.startswith("conf/"):
        exp = 0o640
    else:
        exp = 0o644
    if not (m.isdir() or m.isreg()):
        bad(f"{n} is not a regular file or directory")
    if (m.mode & 0o7777) != exp:
        bad(f"{n} has mode {m.mode & 0o7777:04o}, the spec says {exp:04o}")
    if m.uid != 0 or m.gid != 0 or m.uname not in ("", "root") or m.gname not in ("", "root"):
        bad(f"{n} is owned by {m.uname or m.uid}:{m.gname or m.gid}, the spec says root:root (0:0)")
    if m.mtime != 1767225600:
        bad(f"{n} has mtime {m.mtime}, the spec says 1767225600 (2026-01-01 00:00:00 UTC)")
    if m.isreg():
        seen[rel] = hashlib.sha256(tf.extractfile(m).read()).hexdigest()
for p in sorted(want):
    if p not in seen:
        bad(f"{p} is missing from the archive (hidden files that belong to the product must ship)")
    if seen[p] != want[p]:
        bad(f"{p} differs from the source file")
for p in seen:
    if p not in want:
        bad(f"unexpected file in the archive: {p}")
if names != sorted(names, key=lambda s: s.encode()):
    bad("the members are not sorted by name")
PY
sleep 2
find src -exec touch {} + 2>/dev/null
rm -rf dist
if ! TZ=Asia/Tokyo timeout 25 bash build.sh >.lm/build2.log 2>&1 || [ ! -f "$ART" ]; then
  echo "❌ the second run of build.sh failed (it must work when dist/ does not exist yet)"
  exit 1
fi
if ! cmp -s .lm/build1.tgz "$ART"; then
  echo "❌ the archive is right but two builds differ (sha256 $(sha256sum < .lm/build1.tgz | cut -c1-8) vs $(sha256sum < "$ART" | cut -c1-8)): something still depends on the time or the files' timestamps"
  exit 1
fi
echo "✅ dist/agent-1.4.2.tar.gz matches the spec and builds identically twice"
