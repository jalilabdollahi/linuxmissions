#!/bin/bash
# Two VM images, scaled down. vm1.img is properly sparse (a big apparent size, a
# few MiB of data). vm2.img was written by dd from /dev/zero, so it has the same
# kind of content but every block is allocated: cp --sparse=auto and tar -S
# both trust the file system's idea of holes and see none in it. Sizes and the
# places of the data change per run.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state vm
cd vm || exit 1

A=$((192 + 64 * (RANDOM % 3)))     # vm1 apparent MiB
B=$((96 + 32 * (RANDOM % 3)))      # vm2 apparent MiB

# put FILE OFFSET_MiB SIZE_KiB: random data in the middle of the image
put() { head -c $(($3 * 1024)) /dev/urandom | dd of="$1" bs=4096 seek=$(($2 * 256)) conv=notrunc status=none; }

truncate -s "${A}M" vm1.img
dd if=/dev/zero of=vm2.img bs=1M count="$B" status=none
for img in vm1.img vm2.img; do
  max=$A; [ "$img" = vm2.img ] && max=$B
  # 3 chunks of 256-1024 KiB, one in each third of the image
  for k in 0 1 2; do
    off=$(( (max / 3) * k + RANDOM % (max / 3 - 2) ))
    put "$img" "$off" $((256 + 256 * (RANDOM % 4)))
  done
done
sync
sha256sum vm1.img vm2.img > ../.lm-state/orig.sums
cd ..

cat > TICKET.txt <<'EOF'
The weekly backup of the two VM images (vm/vm1.img and vm/vm2.img) used to be a
few MB and has ballooned. (In production the images are 20 GB each; the ones
here are small copies with the same shape.) Please:

 1. sizes.txt: for each image, one line "NAME APPARENT_BYTES ALLOCATED_KIB":
    the size the file claims to have, and the disk space it really uses in KiB
    (1 KiB = 1024 bytes). Report the two originals, as they are now.
 2. vm2-copy.img: a copy of vm/vm2.img that is byte-for-byte identical but does
    not take up all that space.
 3. vm-backup.tar: an uncompressed tar of vm1.img (member name vm1.img) that
    stays small and stores the file as a sparse file.
Do not modify the two original images.
EOF
