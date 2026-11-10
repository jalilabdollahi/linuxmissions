#!/bin/bash
# srv/projects/apollo: a messy tree, all owned by the player (no root needed, so
# the group is the player's own). Mixed modes on directories and files, hidden
# files and directories, names with spaces, a read-only file in an r-x
# directory, an executable that is 777, and a symlink to a file OUTSIDE the
# tree (srv/shared/vendor-notes.txt, 644) that a careless find|chmod would
# change through the link. .lm-state keeps the list of entries and which files
# were executable.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state
python3 - <<'PY'
import os
T = "srv/projects/apollo"
dirs = {  # path: mode
    "": 0o755, "bin": 0o755, "src": 0o775, "src/.cache": 0o700, "docs": 0o2755, "docs/drafts": 0o750,
    "data": 0o777, "data/archive 2025": 0o500, "data/incoming": 0o1777,
}
files = {  # path: mode
    "README.md": 0o644, ".env": 0o600, ".gitignore": 0o664,
    "bin/build.sh": 0o755, "bin/deploy.sh": 0o700, "bin/helper": 0o777,
    "src/main.c": 0o644, "src/util.c": 0o666, "src/util.h": 0o644, "src/.cache/obj.o": 0o600, "src/.cache/.stamp": 0o600,
    "docs/design.md": 0o644, "docs/drafts/todo.txt": 0o640, "docs/Q3 plan.md": 0o644,
    "data/raw.csv": 0o666, "data/archive 2025/2025.tar": 0o444, "data/incoming/upload.part": 0o666,
}
for d in sorted(dirs):
    os.makedirs(os.path.join(T, d), exist_ok=True)
for f, m in files.items():
    p = os.path.join(T, f)
    with open(p, "w") as fh:
        fh.write("#!/bin/sh\necho apollo\n" if m & 0o111 else "apollo project file: %s\n" % f)
    os.chmod(p, m)
os.makedirs("srv/shared", exist_ok=True)
with open("srv/shared/vendor-notes.txt", "w") as fh:
    fh.write("vendor contact sheet\n")
os.chmod("srv/shared/vendor-notes.txt", 0o644)
os.symlink("../../shared/vendor-notes.txt", os.path.join(T, "docs/vendor-notes.txt"))
# modes last, deepest first, so the read-only directory does not block us
for d in sorted(dirs, key=lambda x: -x.count("/") - (1 if x else 0)):
    os.chmod(os.path.join(T, d) if d else T, dirs[d])
os.chmod("srv/projects", 0o755)
with open(".lm-state/exec", "w") as fh:
    fh.write("\n".join(f for f, m in files.items() if m & 0o111) + "\n")
PY
( cd srv/projects/apollo && find . | LC_ALL=C sort ) > .lm-state/entries
ls -ld srv/shared/vendor-notes.txt | awk '{print $1}' > .lm-state/vendor.mode
cat > TICKET.md <<'LMEND'
# SEC-512: Apollo shared directory

srv/projects/apollo is used by the whole Apollo team (one Unix group) and
nobody else may see it.

Wanted, for the directory itself, every subdirectory and every file (hidden
ones too):

  directories      full access for the owner and the team, nothing for others;
                   new files and directories created inside inherit the team's
                   group; nobody but the file's owner may delete or rename
                   someone else's files
  regular files    read/write for owner and team, nothing for others;
                   files that are executable today stay executable (for owner
                   and team)

docs/vendor-notes.txt is a symlink to a shared vendor file outside the
project: leave both the link and the vendor file alone.
LMEND
