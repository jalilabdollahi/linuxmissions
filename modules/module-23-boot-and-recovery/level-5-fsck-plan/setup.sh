#!/bin/bash
# Offline Filesystem Repair. Builds an 8 MB ext4 image with mke2fs -d, then damages
# it with debugfs -w (works on a plain file, no root): one inode is cleared (its
# directory entry now points at nothing) and another inode's link count is wrong.
# The superblock still says "clean", like after a lucky power cut, so a plain
# "e2fsck -y" skips the check: the player needs -f.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
export PATH="$PATH:/sbin:/usr/sbin"
for t in mke2fs e2fsck debugfs dumpe2fs; do command -v $t >/dev/null || { echo "setup needs e2fsprogs ($t)" >&2; exit 1; }; done
mkdir -p .lm-state
T=$(mktemp -d)
mkdir -p "$T/reports" "$T/archive"
for i in 1 2 3 4 5 6; do seq 1 $((i * 300)) > "$T/reports/q$i.txt"; done
echo "datavol: quarterly exports" > "$T/README"
for i in 1 2 3; do head -c 40000 /dev/urandom > "$T/archive/blob$i.bin"; done
( cd "$T" && cksum README reports/q1.txt reports/q2.txt reports/q4.txt reports/q6.txt archive/blob1.bin archive/blob2.bin archive/blob3.bin ) > .lm-state/files
mke2fs -q -t ext4 -F -L datavol -d "$T" data.img 8M >/dev/null 2>&1 || { echo "mke2fs failed" >&2; exit 1; }
rm -rf "$T"
q5=$(debugfs -R "stat /reports/q5.txt" data.img 2>/dev/null | awk '/^Inode:/ {print $2}')
q4=$(debugfs -R "stat /reports/q4.txt" data.img 2>/dev/null | awk '/^Inode:/ {print $2}')
[ -n "$q5" ] && [ -n "$q4" ] || { echo "debugfs lookup failed" >&2; exit 1; }
debugfs -w -R "clri <$q5>" data.img >/dev/null 2>&1
debugfs -w -R "sif <$q4> links_count 3" data.img >/dev/null 2>&1
e2fsck -fn data.img >/dev/null 2>&1
[ $? -eq 4 ] || { echo "image damage did not take" >&2; exit 1; }
dumpe2fs -h data.img 2>/dev/null | awk '/^Filesystem UUID:/ {print $3}' > .lm-state/uuid
stat -c %s data.img > .lm-state/size
