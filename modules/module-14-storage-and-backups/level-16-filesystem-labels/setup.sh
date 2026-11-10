#!/bin/bash
# Two small ext4 images. The shop's live data is on one and the nightly backups on the
# other, but their file names (and their current labels) cannot be trusted: which is
# which is picked at random. etc/fstab mounts both by kernel device name.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state etc
pick() { local a=("$@"); echo "${a[RANDOM % ${#a[@]}]}"; }

W=$(mktemp -d "$SANDBOX/.lm-state/build.XXXXXX") || exit 1
trap 'rm -rf "$W"' EXIT
mkdir -p "$W/live/db" "$W/live/uploads" "$W/bak/nightly" "$W/bak/weekly"
head -c $((200000 + RANDOM)) /dev/urandom > "$W/live/db/shop.sqlite"
echo "journal_mode=wal" > "$W/live/db/shop.conf"
for i in $(seq 1 $((3 + RANDOM % 4))); do head -c $((5000 + RANDOM)) /dev/urandom > "$W/live/uploads/img-$RANDOM.jpg"; done
for i in 1 2 3 4; do head -c $((50000 + RANDOM)) /dev/urandom > "$W/bak/nightly/shop-2026-11-0$i.tar.gz"; done
head -c 90000 /dev/urandom > "$W/bak/weekly/shop-week-44.tar.gz"
echo "restic-style retention: 7 nightly, 4 weekly" > "$W/bak/README.backup"

mkimg() {  # name label contentdir
  rm -f "$1"
  mke2fs -q -F -t ext4 -b 1024 -L "$2" -d "$3" "$1" 6M >/dev/null 2>&1 || { echo "mke2fs failed" >&2; exit 1; }
}
# lie: the file called data.img holds the backups (and vice versa) half of the time;
# the current labels are swapped, generic or empty, never the right ones
if (( RANDOM % 2 )); then A=live; B=bak; else A=bak; B=live; fi
l1=$(pick disk1 vol-a old-disk); l2=$(pick disk2 vol-b spare)
mkimg data.img "$l1" "$W/$A"
mkimg backup.img "$l2" "$W/$B"
data_img=data.img; [ "$A" = live ] || data_img=backup.img
uuid=$(dumpe2fs -h "$data_img" 2>/dev/null | awk '/^Filesystem UUID:/ {print $3}')
echo "$uuid" > .lm-state/data-uuid
other=backup.img; [ "$data_img" = data.img ] || other=data.img
echo "$(dumpe2fs -h "$other" 2>/dev/null | awk '/^Filesystem UUID:/ {print $3}')" > .lm-state/backup-uuid

dv=$(pick "/dev/sdb1 /dev/sdc1" "/dev/vdb1 /dev/vdc1" "/dev/sdc1 /dev/sdd1")
d1=${dv% *}; d2=${dv#* }
cat > etc/fstab <<EOT
# /etc/fstab: static file system information for web-02
UUID=$(cat /proc/sys/kernel/random/uuid)  /         ext4  errors=remount-ro  0  1
UUID=$(cat /proc/sys/kernel/random/uuid)  none      swap  sw                 0  0
$d1   /srv/data    ext4  defaults,noatime,nofail           0  2
$d2   /srv/backup  ext4  defaults,nofail,x-systemd.automount  0  2
tmpfs  /tmp  tmpfs  defaults,size=512m  0  0
EOT
cp etc/fstab .lm-state/fstab.orig

cat > TICKET.txt <<'EOT'
web-02 reboots reshuffle the disks: last Tuesday /dev/sdb1 and /dev/sdc1 traded
places and the backup job wrote its tarballs onto the live data disk. Stop relying
on device names.

- Find out which of the two images, data.img and backup.img, really holds the
  shop's live data (the database and uploads) and which holds the nightly backups.
  Do not trust the file names or the labels they carry now.
- Label the live-data file system DATA and the backup file system BACKUP.
  Do not reformat anything; the data must stay on its file system.
- etc/fstab: mount /srv/data by LABEL=DATA and /srv/backup by LABEL=BACKUP.
  Keep the mount points and all other fields and lines exactly as they are.
EOT
