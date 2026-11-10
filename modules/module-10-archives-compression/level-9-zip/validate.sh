#!/bin/bash
# handover.zip must mirror handover/ (paths, content, symlink) and keep the
# archive comment it had at the start.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
if [ ! -s .lm-state/tree ] || [ ! -s .lm-state/comment ]; then
  echo "❌ the level's reference data in .lm-state/ is gone; type 'reset'"
  exit 1
fi
now=$(cd handover 2>/dev/null && find . \( -type f -o -type l \) | LC_ALL=C sort | while read -r p; do
  if [ -L "$p" ]; then echo "L $p $(readlink "$p")"; else echo "F $p $(cksum < "$p" | tr ' ' :)"; fi
done)
if [ "$now" != "$(cat .lm-state/tree)" ]; then
  echo "❌ handover/ was changed; it is the source of truth here, leave it alone (type 'reset')"
  exit 1
fi
if [ ! -f handover.zip ]; then
  echo "❌ handover.zip is gone; type 'reset' to get last week's zip back"
  exit 1
fi
if [ "$(cksum < handover.zip)" = "$(cat .lm-state/lastweek.sum 2>/dev/null)" ]; then
  echo "❌ handover.zip is still last week's version (compare unzip -l handover.zip with the folder)"
  exit 1
fi

python3 - "$SANDBOX" <<'PY'
import os, stat, sys, zipfile
root = sys.argv[1]
os.chdir(root)

def fail(msg):
    print("❌ " + msg)
    sys.exit(1)

try:
    z = zipfile.ZipFile("handover.zip")
except zipfile.BadZipFile:
    fail("handover.zip is not a valid zip file")

want_comment = open(".lm-state/comment", encoding="utf-8").read().strip()
got_comment = z.comment.decode("utf-8", "replace").strip()

# Files and links on disk, as zip member names.
disk = {}
for dirpath, dirnames, filenames in os.walk("handover"):
    for n in dirnames + filenames:
        p = os.path.join(dirpath, n)
        if os.path.islink(p) or os.path.isfile(p):
            disk[p] = p
members = {i.filename: i for i in z.infolist() if not i.filename.endswith("/")}

odd = sorted(m for m in members if not m.startswith("handover/"))
if odd:
    fail(f"handover.zip has a member '{odd[0]}' outside handover/; member paths must start with handover/")
gone = sorted(set(members) - set(disk))
if gone:
    fail(f"handover.zip still holds {gone[0]}, which was deleted from the folder ({len(gone)} stale member(s)); an update alone never removes anything")
missing = sorted(set(disk) - set(members))
if missing:
    fail(f"handover.zip has no {missing[0]} yet")

link = "handover/docs/latest"
info = members[link]
mode = info.external_attr >> 16
if not stat.S_ISLNK(mode):
    fail(f"{link} is stored as a regular file (a copy of what it points to), not as a symlink")
target = z.read(info).decode("utf-8", "replace")
if target != os.readlink(link):
    fail(f"{link} in the zip still points to {target}; on disk it points to {os.readlink(link)}")

for name, info in sorted(members.items()):
    if name == link:
        continue
    with open(name, "rb") as fh:
        if z.read(info) != fh.read():
            fail(f"{name} in the zip is last week's version; it differs from the folder")

if got_comment != want_comment:
    if not got_comment:
        fail("the contents are right, but the archive comment is gone (a zip built from scratch has none); the portal needs it")
    fail(f"the archive comment changed; it must still read: {want_comment}")
print(f"✅ handover.zip matches handover/ ({len(members)} entries, docs/latest as a link) and kept its comment")
PY
