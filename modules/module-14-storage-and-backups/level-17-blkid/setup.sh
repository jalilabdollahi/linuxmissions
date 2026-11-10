#!/bin/bash
# images/ holds five unlabeled-by-name disk images in random roles: an ext2, an
# ext4, a swap area, a partitioned disk (DOS table: ext4 partition + swap partition)
# and a blank one. The expected inventory is written from the UUIDs and labels chosen
# here, not from blkid.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state images
W=$(mktemp -d "$SANDBOX/.lm-state/build.XXXXXX") || exit 1
trap 'rm -rf "$W"' EXIT
uuid() { cat /proc/sys/kernel/random/uuid; }
pick() { local a=("$@"); echo "${a[RANDOM % ${#a[@]}]}"; }

names=($(printf '%s\n' alpha bravo charlie delta echo foxtrot golf hotel juliet kilo lima | shuf | head -5))
roles=(ext2 ext4 swap disk blank)
: > .lm-state/expect
add() { printf '%s,%s,%s,%s\n' "$1" "$2" "$3" "$4" >> .lm-state/expect; }
maybe_label() { case $((RANDOM % 3)) in 0) echo "";; *) echo "$(pick DATA logs web01 SPARE Scratch bk2026 cache)";; esac; }

for i in 0 1 2 3 4; do
  f="images/${names[i]}.img"; role=${roles[i]}
  case $role in
    ext2|ext4)
      u=$(uuid); l=$(maybe_label)
      mkdir -p "$W/c"; echo "$RANDOM" > "$W/c/f$RANDOM.txt"
      mke2fs -q -F -t "$role" -U "$u" ${l:+-L "$l"} -d "$W/c" "$f" 4M >/dev/null 2>&1 || exit 1
      add "${names[i]}.img" "$role" "$u" "$l" ;;
    swap)
      u=$(uuid); l=$(pick swp0 swap-a ""); truncate -s 3M "$f"
      mkswap -q -U "$u" ${l:+-L "$l"} "$f" >/dev/null 2>&1 || exit 1
      add "${names[i]}.img" swap "$u" "$l" ;;
    disk)
      truncate -s 8M "$f"
      printf 'label: dos\nlabel-id: 0x%08x\nstart=2048, size=8192, type=83\nstart=10240, size=4096, type=82\n' $((RANDOM * 32768 + RANDOM)) | sfdisk -q "$f" >/dev/null 2>&1 || exit 1
      u1=$(uuid); l1=$(maybe_label); u2=$(uuid); l2=$(pick swp1 "")
      mke2fs -q -F -t ext4 -U "$u1" ${l1:+-L "$l1"} "$W/p1" 4M >/dev/null 2>&1 || exit 1
      truncate -s 2M "$W/p2"; mkswap -q -U "$u2" ${l2:+-L "$l2"} "$W/p2" >/dev/null 2>&1 || exit 1
      dd if="$W/p1" of="$f" bs=512 seek=2048 conv=notrunc status=none
      dd if="$W/p2" of="$f" bs=512 seek=10240 conv=notrunc status=none
      add "${names[i]}.img@p1" ext4 "$u1" "$l1"
      add "${names[i]}.img@p2" swap "$u2" "$l2" ;;
    blank)
      truncate -s 2M "$f"
      add "${names[i]}.img" "" "" "" ;;
  esac
done
LC_ALL=C sort -o .lm-state/expect .lm-state/expect

cat > TICKET.txt <<'EOT'
Finance dropped a box of disk images on us ("some are backups, some are not")
and nobody remembers what is what. Before anything is mounted or deleted, build
an inventory of what is really in images/.

Write inventory.csv in this folder:
  - the first line is exactly:  file,TYPE,UUID,LABEL
  - one line per image, in any order. file is the file name without the
    directory (e.g. alpha.img), TYPE the file system or swap signature
    (ext2, ext4, swap...), UUID and LABEL as blkid reports them. A field the
    image does not have stays empty (two commas in a row).
  - an image with a partition table has no file system of its own: write one
    line per partition instead, named FILE@p1, FILE@p2 (numbered in table
    order), with the type, UUID and label of the file system inside it. No
    line for the whole disk image.
  - an image with nothing recognisable gets a line with empty TYPE, UUID, LABEL.
Commands that need root are not available; blkid can read an image file
directly when it is told to probe it (see man blkid).
EOT
