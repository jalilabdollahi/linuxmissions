#!/bin/bash
# Inside the initrd: a gzipped newc cpio built like an initramfs (member names
# without a leading ./), with a random set of kernel modules.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state initrd-root
B=.lm-state/initrd
K=usr/lib/modules/6.8.0-48-generic
mkdir -p "$B/bin" "$B/scripts/local-top" "$B/conf" "$B/etc/modprobe.d" "$B/etc/udev/rules.d" "$B/$K/kernel"

pool="drivers/nvme/host/nvme.ko drivers/nvme/host/nvme-core.ko drivers/ata/ahci.ko drivers/ata/libahci.ko
drivers/scsi/virtio_scsi.ko drivers/block/virtio_blk.ko drivers/net/virtio_net.ko drivers/net/ethernet/intel/e1000e/e1000e.ko
drivers/net/ethernet/intel/igb/igb.ko drivers/net/ethernet/broadcom/tg3.ko drivers/md/dm-crypt.ko drivers/md/dm-mod.ko
drivers/md/raid1.ko drivers/md/raid10.ko drivers/md/raid456.ko drivers/usb/storage/usb-storage.ko drivers/hid/usbhid/usbhid.ko
drivers/hid/hid-generic.ko fs/btrfs/btrfs.ko fs/xfs/xfs.ko fs/ext4/ext4.ko fs/fat/vfat.ko fs/isofs/isofs.ko
crypto/aesni-intel.ko crypto/crc32c_generic.ko lib/libcrc32c.ko drivers/gpu/drm/drm.ko drivers/gpu/drm/virtio/virtio-gpu.ko
drivers/scsi/megaraid/megaraid_sas.ko drivers/scsi/mpt3sas/mpt3sas.ko drivers/mmc/host/sdhci.ko drivers/thunderbolt/thunderbolt.ko"
for m in $pool; do
  [ $(( RANDOM % 100 )) -lt 55 ] || continue
  mkdir -p "$B/$K/kernel/$(dirname "$m")"
  { printf '\x7fELF\x02\x01\x01'; head -c $(( 512 + RANDOM % 2048 )) /dev/urandom; } > "$B/$K/kernel/$m"
  echo "kernel/$m" >> "$B/$K/modules.order"
done
[ -s "$B/$K/modules.order" ] || { mkdir -p "$B/$K/kernel/fs/ext4"; printf '\x7fELF' > "$B/$K/kernel/fs/ext4/ext4.ko"; echo kernel/fs/ext4/ext4.ko > "$B/$K/modules.order"; }
sed 's/$/:/' "$B/$K/modules.order" > "$B/$K/modules.dep"
printf 'alias pci:v00008086d* e1000e\n' > "$B/$K/modules.alias"

head -c 4096 /dev/urandom > "$B/bin/busybox"
ln -s busybox "$B/bin/sh"
printf '#!/bin/sh\n# initramfs init\nmount -t proc proc /proc\n. /scripts/local-top/cryptroot\nexec run-init /root /sbin/init\n' > "$B/init"
printf '#!/bin/sh\ncryptsetup open /dev/nvme0n1p3 root\n' > "$B/scripts/local-top/cryptroot"
chmod 755 "$B/init" "$B/scripts/local-top/cryptroot" "$B/bin/busybox"
printf 'MODULES=most\nCOMPRESS=gzip\n' > "$B/conf/initramfs.conf"

printf '/dev/mapper/root / ext4 errors=remount-ro 0 1\nUUID=%04X-%04X /boot/efi vfat umask=0077 0 1\n' $RANDOM $RANDOM > "$B/etc/fstab"
printf 'root UUID=%08x-%04x-4%03x-a%03x-%06x%06x none luks,discard\n' $RANDOM$RANDOM $RANDOM $(( RANDOM % 4096 )) $(( RANDOM % 4096 )) $RANDOM $RANDOM > "$B/etc/crypttab"
printf 'blacklist floppy\nblacklist pcspkr\n' > "$B/etc/modprobe.d/blacklist.conf"
printf 'options nvme_core default_ps_max_latency_us=%d\n' $(( RANDOM % 5000 )) > "$B/etc/modprobe.d/nvme.conf"
printf 'SUBSYSTEM=="block", KERNEL=="nvme*", ATTR{queue/scheduler}="none"\n' > "$B/etc/udev/rules.d/60-scheduler.rules"
printf '%032x\n' 0 | sed "s/^0\{8\}/$(printf '%04x%04x' $RANDOM $RANDOM)/" > "$B/etc/machine-id"
ln -s /proc/self/mounts "$B/etc/mtab"

(cd "$B" && find . -mindepth 1 | sed 's|^\./||' | LC_ALL=C sort | cpio -o -H newc --quiet 2>/dev/null) | gzip -9 > initrd.img
cksum < initrd.img > .lm-state/initrd.sum
rm -rf "$B"
