#!/bin/bash
# Kernel Cleanup in /boot. Six kernels, each with vmlinuz/initrd.img/config/System.map
# and a modules directory. Installed: 5.15.0-100, 5.15.0-118, 6.5.0-28, 6.8.0-9,
# 6.8.0-31 (running), 6.8.0-45 (newest). Text sort puts 6.8.0-9 last; the running
# kernel is not the newest. The four links point at old kernels that will be deleted.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p sysroot/boot/grub sysroot/boot/efi sysroot/lib/modules .lm-state
echo 6.8.0-31-generic > uname-r.txt
B=sysroot/boot
for v in 5.15.0-100-generic 5.15.0-118-generic 6.5.0-28-generic 6.8.0-9-generic 6.8.0-31-generic 6.8.0-45-generic; do
  head -c 30000 /dev/urandom > $B/vmlinuz-$v
  head -c 60000 /dev/urandom > $B/initrd.img-$v
  printf '# Linux/x86 %s Kernel Configuration\nCONFIG_64BIT=y\nCONFIG_NVME_CORE=m\n' "$v" > $B/config-$v
  printf 'ffffffff81000000 T _text\nffffffff81000040 T secondary_startup_64 # %s\n' "$v" > $B/System.map-$v
  mkdir -p sysroot/lib/modules/$v/kernel/drivers
  echo "$v" > sysroot/lib/modules/$v/kernel/drivers/nvme.ko
  echo "alias pci:v*d*sv*sd*bc01sc08i02* nvme" > sysroot/lib/modules/$v/modules.alias
done
printf 'set default="1>2"\n' > $B/grub/grub.cfg
echo memtest > $B/memtest86+x64.bin
echo "loader" > $B/efi/BOOTX64.EFI
ln -s vmlinuz-6.5.0-28-generic $B/vmlinuz
ln -s vmlinuz-5.15.0-118-generic $B/vmlinuz.old
ln -s initrd.img-6.5.0-28-generic $B/initrd.img
ln -s initrd.img-5.15.0-118-generic $B/initrd.img.old
( cd sysroot && find boot/grub boot/efi boot/memtest86+x64.bin \
    boot/*-6.8.0-31-generic boot/*-6.8.0-45-generic lib/modules/6.8.0-31-generic lib/modules/6.8.0-45-generic -type f -exec cksum {} + | sort -k3 ) > .lm-state/keep
