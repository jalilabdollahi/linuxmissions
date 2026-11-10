#!/bin/bash
# Which Initramfs Lacks NVMe? Three real initramfs-style archives (cpio newc):
#   6.8.0-45  zstd  has nvme.ko and nvme-core.ko   (good, but zcat cannot read it)
#   6.8.0-31  gzip  has nvme-core.ko only          (the bad one)
#   5.15.0-118 gzip has both                       (good)
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p sysroot/boot .lm-state
command -v cpio >/dev/null && command -v zstd >/dev/null && command -v gzip >/dev/null || { echo "setup needs cpio, gzip and zstd" >&2; exit 1; }

build() {  # build VERSION COMPRESSOR WITH_NVME(yes/no)
  local ver="$1" comp="$2" nv="$3" t
  t=$(mktemp -d)
  mkdir -p "$t/usr/lib/modules/$ver/kernel/drivers/"{nvme/host,ata,scsi,md,block} "$t/usr/bin" "$t/scripts" "$t/conf"
  local m="$t/usr/lib/modules/$ver/kernel/drivers"
  for f in ata/libata ata/ahci ata/libahci scsi/sd_mod scsi/scsi_mod md/dm-mod md/raid1 block/virtio_blk nvme/host/nvme-core; do
    printf 'ELF-stub %s %s\n' "$f" "$ver" > "$m/$f.ko"
  done
  [ "$nv" = yes ] && printf 'ELF-stub nvme %s\n' "$ver" > "$m/nvme/host/nvme.ko"
  printf 'ELF-stub nvme-fabrics %s\n' "$ver" > "$m/nvme/host/nvme-fabrics.ko"
  printf '#!/bin/sh\n# busybox stub\n' > "$t/usr/bin/busybox"; chmod 755 "$t/usr/bin/busybox"
  printf 'MODULES=most\nBUSYBOX=y\nCOMPRESS=%s\n' "$comp" > "$t/conf/initramfs.conf"
  printf '#!/bin/sh\n# local-top: mount the root filesystem\n' > "$t/scripts/local"
  ( cd "$t" && find . | LC_ALL=C sort | cpio -o -H newc --quiet 2>/dev/null ) > "$t/img"
  case "$comp" in
    zstd) zstd -q -19 -c "$t/img" > "sysroot/boot/initrd.img-$ver" ;;
    *)    gzip -9 -c "$t/img" > "sysroot/boot/initrd.img-$ver" ;;
  esac
  rm -rf "$t"
}
build 6.8.0-45-generic zstd yes
build 6.8.0-31-generic gzip no
build 5.15.0-118-generic gzip yes
for v in 6.8.0-45-generic 6.8.0-31-generic 5.15.0-118-generic; do
  : > "sysroot/boot/vmlinuz-$v"
done
cksum sysroot/boot/initrd.img-* > .lm-state/sums
echo initrd.img-6.8.0-31-generic > .lm-state/want
