#!/bin/bash
# releases/ is the source of truth; mirror/ is an older copy that still holds
# files deleted from the source (a whole version dir, a file with a space in its
# name, a nested one, an old symlink target) and outdated copies of changed files.
# mirror/.local-notes/ is the mirror admin's own notes: not in releases/, must
# never be deleted. Tokens in the files are random per run.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state mirror

rnd() { head -c $((300 + RANDOM % 900)) /dev/urandom | base64; }

# the old state, in mirror/
mkdir -p mirror/v0.9 mirror/v1.0/patches mirror/v1.1 mirror/.local-notes mirror/tools
for f in v0.9/app.tar.gz.txt v0.9/CHECKSUMS v1.0/app.tar.gz.txt v1.0/CHECKSUMS "v1.0/release notes.txt" v1.0/patches/001.diff v1.0/patches/002.diff v1.1/app.tar.gz.txt v1.1/CHECKSUMS tools/install.sh index.html; do
  rnd > "mirror/$f"
done
ln -s v1.0 mirror/latest
rnd > mirror/.local-notes/why-this-mirror.txt
rnd > mirror/.local-notes/sync-log.txt
cp -a mirror releases
rm -rf releases/.local-notes

# what changed at the source since: v0.9 gone, patches cleaned, a note dropped,
# v1.1 rebuilt, v1.2 added, latest moved, an installer rewritten
rm -rf releases/v0.9
rm -f releases/v1.0/patches/002.diff "releases/v1.0/release notes.txt"
[ $((RANDOM % 2)) = 0 ] && rm -f releases/v1.0/patches/001.diff && rmdir releases/v1.0/patches
rnd >> releases/v1.1/app.tar.gz.txt
rnd > releases/v1.1/CHECKSUMS
mkdir -p releases/v1.2
rnd > releases/v1.2/app.tar.gz.txt; rnd > releases/v1.2/CHECKSUMS
rm releases/latest; ln -s v1.2 releases/latest
rnd > releases/tools/install.sh
rm -f releases/index.html

# the plan the validator expects: the deletions of a dry run with the notes protected
rsync -a -n -i --delete --exclude=/.local-notes releases/ mirror/ | grep '^\*deleting' |
  sed 's/^\*deleting  *//' | LC_ALL=C sort > .lm-state/plan
find mirror/.local-notes -type f -exec sha256sum {} + | sort > .lm-state/notes.sums

cat > TICKET.txt <<'EOF'
mirror/ is the public mirror of releases/, but it has drifted: releases that were
pulled from the source are still being served, and some files are out of date.

Make mirror/ an exact copy of releases/, removing what no longer exists at the
source, with one exception: mirror/.local-notes/ is the mirror admin's private
notes. It is not part of releases/ and must survive untouched.

Before changing anything, save a dry run so the team can review it: plan.txt
must contain exactly the lines that announce deletions (the "*deleting" lines)
that the real run is going to carry out, and nothing else.
EOF
