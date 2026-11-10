#!/bin/bash
# The image whose UUID belongs to the live data must carry label DATA and the other
# BACKUP; neither was re-made; fstab differs from the original only in the first
# field of the two mount lines.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
for f in data.img backup.img etc/fstab; do [ -f "$f" ] || { echo "❌ $f is missing"; exit 1; }; done
du_=$(cat .lm-state/data-uuid); bu=$(cat .lm-state/backup-uuid)
check() {  # image want-label
  local uuid lab
  uuid=$(dumpe2fs -h "$1" 2>/dev/null | awk '/^Filesystem UUID:/ {print $3}')
  [ -n "$uuid" ] || { echo "❌ $1 is no longer a readable ext file system"; exit 1; }
  echo "$uuid"
}
for img in data.img backup.img; do
  u=$(check "$img") || exit 1
  if [ "$u" != "$du_" ] && [ "$u" != "$bu" ]; then
    echo "❌ $img has a new UUID: the file systems must not be re-made (mke2fs/tune2fs -U); only labels change"
    exit 1
  fi
  lab=$(dumpe2fs -h "$img" 2>/dev/null | sed -n 's/^Filesystem volume name: *//p')
  if [ "$u" = "$du_" ]; then
    [ "$lab" = DATA ] || { if [ "$lab" = BACKUP ]; then echo "❌ the image labelled BACKUP ($img) is the one that holds the live database and uploads"; else echo "❌ the file system with the live data has label '$lab', it should be DATA"; fi; exit 1; }
  else
    [ "$lab" = BACKUP ] || { if [ "$lab" = DATA ]; then echo "❌ the image labelled DATA ($img) is the one that holds the nightly backups"; else echo "❌ the file system with the backups has label '$lab', it should be BACKUP"; fi; exit 1; }
  fi
done
if [ "$(dumpe2fs -h data.img 2>/dev/null | awk '/^Filesystem UUID:/ {print $3}')" = "$(dumpe2fs -h backup.img 2>/dev/null | awk '/^Filesystem UUID:/ {print $3}')" ]; then
  echo "❌ both images have the same UUID"; exit 1
fi
want=$(awk '$2=="/srv/data" {$1="LABEL=DATA"} $2=="/srv/backup" {$1="LABEL=BACKUP"} {$1=$1} 1' .lm-state/fstab.orig)
got=$(awk '{$1=$1} 1' etc/fstab)
if [ "$got" != "$want" ]; then
  d=$(awk '$2=="/srv/data" {print $1}' etc/fstab); b=$(awk '$2=="/srv/backup" {print $1}' etc/fstab)
  if [ "$d" != "LABEL=DATA" ]; then echo "❌ /srv/data is mounted from '$d', it should use LABEL=DATA"
  elif [ "$b" != "LABEL=BACKUP" ]; then echo "❌ /srv/backup is mounted from '$b', it should use LABEL=BACKUP"
  else echo "❌ something else in etc/fstab changed (options, mount points, other lines): only the first field of the two lines should"; fi
  exit 1
fi
echo "✅ the live data is labelled DATA, the backups BACKUP, and fstab mounts both by label"
