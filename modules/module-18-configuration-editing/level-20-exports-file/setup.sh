#!/bin/bash
# etc/exports as the security scanner found it: a space between the subnet and "(rw...)" (so the
# subnet gets defaults and the whole world gets rw), no_root_squash on the ISO mirror. The
# host's export table is built from it, as after the last "exportfs -r".
SANDBOX="$1"
cd "$SANDBOX" || exit 1
HERE="$(cd "$(dirname "$0")" && pwd)"
mkdir -p etc srv/builds srv/iso srv/backup bin var/lib/nfs .lm-state

BK="10.20.5.$((RANDOM % 200 + 10))"
cat > etc/exports <<EXPORTS
# /etc/exports - NFS exports of fs-01, see exports(5)
# CI build artifacts: written by the build farm only
/srv/builds   10.20.0.0/24 (rw,sync,no_subtree_check)
# ISO mirror: everybody may read
/srv/iso      *(ro,sync,no_subtree_check,no_root_squash)
# nightly backup target (do not touch)
/srv/backup   $BK(rw,sync,no_subtree_check)
EXPORTS
cp etc/exports .lm-state/exports.orig

cp "$HERE/exportfs.py" bin/exportfs
chmod 755 bin/exportfs
bin/exportfs -r
