#!/bin/bash
# The vendor wants partition 2 of disk.img as its own image, p2.img, and sent a
# SHA-256 of what it should be. Three partitions with an ext4 file system each;
# partition 2 starts at an odd sector (not on a MiB boundary), so bs=1M skip=<sector>
# is wrong in two ways. Layout, labels and contents change on every run.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

s1=2048
n1=$((2 * 4096 + 8 * (RANDOM % 1000)))                  # sectors, even
s2=$((s1 + n1 + 8 * (50 + RANDOM % 500)))               # starts on a multiple of 8, not of 2048
n2=$((2 * 8192 + 8 * (RANDOM % 1500)))
s3=$((s2 + n2 + 8 * (50 + RANDOM % 500)))
n3=$((2 * 4096 + 8 * (RANDOM % 1000)))
total=$((s3 + n3 + 2048))
truncate -s $((total * 512)) disk.img

printf 'label: dos\ndisk.img1 : start=%s, size=%s, type=83\ndisk.img2 : start=%s, size=%s, type=83\ndisk.img3 : start=%s, size=%s, type=83\n' \
  "$s1" "$n1" "$s2" "$n2" "$s3" "$n3" | sfdisk -q disk.img >/dev/null 2>&1 || { echo "setup: sfdisk failed" >&2; exit 1; }

i=0
for part in "$s1:$n1:boot" "$s2:$n2:appdata" "$s3:$n3:spare"; do
  IFS=: read -r s n label <<< "$part"
  mke2fs -q -F -t ext4 -L "$label" -E offset=$((s * 512)) disk.img $((n / 2))k >/dev/null 2>&1 || { echo "setup: mke2fs failed" >&2; exit 1; }
done

expect=$(dd if=disk.img bs=512 skip="$s2" count="$n2" status=none | sha256sum | cut -d' ' -f1)
printf '%s  p2.img\n' "$expect" > vendor.sha256
printf 'EXPECT=%s\nBYTES=%s\n' "$expect" $((n2 * 512)) > .lm-state/spec
sha256sum disk.img > .lm-state/disk.sum

cat > TICKET.txt <<'EOF'
Our vendor wants only the application partition (partition 2) of disk.img
for analysis. Cut partition 2 out of the disk image into a file of its own,
p2.img, and make sure it is byte-for-byte what the vendor expects: their
checksum is in vendor.sha256. Do not modify disk.img.
EOF
