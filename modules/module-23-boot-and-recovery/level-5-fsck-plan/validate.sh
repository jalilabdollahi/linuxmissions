#!/bin/bash
# Image must now pass e2fsck -fn (exit 0), the evidence log must come from a
# repair run on this filesystem, the exit code file must say 1, UUID unchanged,
# surviving files intact.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
export PATH="$PATH:/sbin:/usr/sbin"

[ -f data.img ] || { echo "❌ data.img is missing"; exit 1; }
if [ "$(stat -c %s data.img)" != "$(cat .lm-state/size)" ]; then
  echo "❌ data.img changed size; repair it in place, do not recreate it"
  exit 1
fi
if [ "$(dumpe2fs -h data.img 2>/dev/null | awk '/^Filesystem UUID:/ {print $3}')" != "$(cat .lm-state/uuid)" ]; then
  echo "❌ the filesystem UUID changed: this is not the original filesystem any more"
  exit 1
fi
e2fsck -fn data.img >/dev/null 2>&1
rc=$?
if [ $rc -ne 0 ]; then
  echo "❌ a forced read-only check of data.img still exits $rc: the image has not been repaired"
  exit 1
fi
want=$(cat .lm-state/files)
got=$(echo "$want" | while read -r sum size name; do
  printf '%s ' "$(debugfs -R "cat /$name" data.img 2>/dev/null | cksum | awk '{print $1, $2}')"; echo "$name"
done)
if [ "$got" != "$want" ]; then
  echo "❌ some files that should have survived are damaged or gone from data.img"
  exit 1
fi
if [ ! -s fsck.log ]; then
  echo "❌ fsck.log is missing or empty: keep the repair output (a redirect captures it)"
  exit 1
fi
if ! grep -q '^Pass 1: Checking inodes' fsck.log || ! grep -q 'datavol' fsck.log; then
  echo "❌ fsck.log does not look like e2fsck output for datavol"
  exit 1
fi
if ! grep -q 'FILE SYSTEM WAS MODIFIED' fsck.log; then
  echo "❌ fsck.log shows no repair (no 'FILE SYSTEM WAS MODIFIED' line): it has to be the log of the run that fixed the image"
  exit 1
fi
if [ ! -s fsck_exit.txt ]; then
  echo "❌ fsck_exit.txt does not exist yet"
  exit 1
fi
code=$(tr -d '[:space:]' < fsck_exit.txt)
case "$code" in
  1) ;;
  0) echo "❌ fsck_exit.txt says 0, but the repair run found problems; that is the code of a run that finds nothing to fix"; exit 1 ;;
  4) echo "❌ fsck_exit.txt says 4, the code of a run that left errors uncorrected; the run that repaired the image exits differently"; exit 1 ;;
  *) echo "❌ fsck_exit.txt says '$code'; write the exit code of the repair run (man e2fsck, EXIT CODE)"; exit 1 ;;
esac
echo "✅ data.img is clean again, fsck.log holds the repair, and its exit code 1 means errors were corrected"
exit 0
