#!/bin/bash
# After a disk swap the server boots into emergency mode: etc/fstab still holds
# the old disks' UUIDs. blkid.txt is the new disks. UUIDs and PARTUUIDs are random
# per run (PARTUUIDs are full UUID-shaped on purpose). Four entries to repair:
# wrong UUIDs everywhere, root has pass 0, /srv/data has pass 1, the USB backup
# disk (removable) lacks nofail. Validator parses the six fields.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p etc .lm-state

uuid() { cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen | tr 'A-Z' 'a-z'; }
ROOT=$(uuid); SWAP=$(uuid); DATA=$(uuid); USB=$(uuid)
OLD1=$(uuid); OLD2=$(uuid); OLD3=$(uuid); OLD4=$(uuid)
DTYPE=$( [ $((RANDOM % 2)) = 0 ] && echo xfs || echo ext4 )

cat > etc/fstab <<EOF
# /etc/fstab: static file system information.
#
# <file system>  <mount point>  <type>  <options>  <dump>  <pass>
# root disk
UUID=$OLD1  /  ext4  errors=remount-ro  0  0
# swap
UUID=$OLD2  none  swap  sw  0  0
# application data (second disk)
UUID=$OLD3  /srv/data  $DTYPE  defaults,noatime  0  1
# removable USB disk for the nightly backup
UUID=$OLD4  /mnt/usb-backup  ext4  defaults,noauto,x-systemd.automount  0  2
EOF

cat > blkid.txt <<EOF
/dev/loop0: TYPE="squashfs"
/dev/vda1: LABEL="root" UUID="$ROOT" BLOCK_SIZE="4096" TYPE="ext4" PARTLABEL="root" PARTUUID="$(uuid)"
/dev/vda2: UUID="$SWAP" TYPE="swap" PARTLABEL="swap" PARTUUID="$(uuid)"
/dev/vdb1: LABEL="data" UUID="$DATA" BLOCK_SIZE="4096" TYPE="$DTYPE" PARTLABEL="data" PARTUUID="$(uuid)"
/dev/vdc1: LABEL="usb-backup" UUID="$USB" BLOCK_SIZE="4096" TYPE="ext4" PARTUUID="$(uuid)"
EOF
PARTS=$(sed -n 's/.* PARTUUID="\([^"]*\)".*/\1/p' blkid.txt | tr '\n' ' ')

cat > TICKET.txt <<'EOF'
web-07 has been in emergency mode since the disk swap on Monday.
The new disks are listed in blkid.txt (output of `blkid` after the swap):
  /dev/vda1  root,   /dev/vda2  swap,   /dev/vdb1  application data,
  /dev/vdc1  the removable USB backup disk (sometimes it is not plugged in).
etc/fstab is a copy of the server's file and still has the old disks' IDs.
Fix etc/fstab: every entry must refer to its new disk by UUID=, and the machine
must still boot when the USB disk is missing. Check the last column too:
the root file system is checked first, the rest after it (or not at all).
Keep the comments and each entry's other settings.
EOF

cp etc/fstab .lm-state/orig.fstab
printf 'ROOT=%s\nSWAP=%s\nDATA=%s\nUSB=%s\nDTYPE=%s\nPARTS="%s"\n' "$ROOT" "$SWAP" "$DATA" "$USB" "$DTYPE" "$PARTS" > .lm-state/spec
cksum blkid.txt > .lm-state/blkid.sum
