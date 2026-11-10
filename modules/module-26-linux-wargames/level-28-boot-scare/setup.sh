#!/bin/bash
# Wargame 28: boot chain of a cloned disk, checked by a level-local boot-sim.
# Chain of faults: default entry 1>1 (kernel 6.8.0-52 recovery) has no initrd
# file; the right entry (1>2) still has the old root/boot UUIDs on its lines;
# the 6.8.0-45 recovery entry uses an initrd without the root disk's driver;
# fstab has old UUIDs and a /data disk that is gone (needs nofail); default.target
# is mistyped and a vendor unit's ExecStart moved.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
M="$(cd "$(dirname "$0")/../../../mocks" && pwd)"
rm -rf sysroot boot-sim blkid.txt .mock .lm
mkdir -p .mock .lm sysroot/boot/grub sysroot/dev/disk/by-uuid sysroot/dev/disk/by-label sysroot/proc \
         sysroot/etc/systemd/system/multi-user.target.wants sysroot/opt/agent/bin
cp "$(dirname "$0")/boot-sim" boot-sim; chmod 755 boot-sim
cp "$M/systemd/systemctl" .mock/systemctl
uu() { python3 -c 'import uuid; print(uuid.uuid4())'; }
OLDR=$(uu); OLDB=$(uu); OLDS=$(uu); OLDD=$(uu); NEWR=$(uu); NEWB=$(uu); NEWS=$(uu)
cd sysroot
for v in 6.8.0-52-generic 6.8.0-45-generic; do head -c 4000 /dev/urandom > boot/vmlinuz-$v; done
printf 'initramfs 6.8.0-45-generic\nmodule ext4\nmodule virtio_net\nmodule virtio_scsi\nmodule sd_mod\n' > boot/initrd.img-6.8.0-45-generic
printf 'initramfs 6.8.0-45 recovery (hostonly, built on the old VM)\nmodule ext4\nmodule virtio_blk\n' > boot/initrd.img-6.8.0-45-recovery
ln -s ../../sda1 dev/disk/by-uuid/$NEWB; ln -s ../../sda2 dev/disk/by-uuid/$NEWR; ln -s ../../sda3 dev/disk/by-uuid/$NEWS
ln -s ../../sda2 dev/disk/by-label/cloudimg-rootfs
printf 'sda virtio_scsi\nvda virtio_blk\n' > proc/driver-map
DEFS=("1>1" "1>0" "0")
DEF=${DEFS[RANDOM % 3]}
ent() {  # title id kernel initrd
cat <<E
    menuentry '$1' --class ubuntu --id $2 {
        search --no-floppy --fs-uuid --set=root $OLDB
        linux /boot/vmlinuz-$3 root=UUID=$OLDR ro quiet splash
        initrd /boot/$4
    }
E
}
{
echo "set default=\"$DEF\""
echo "set timeout=5"
echo "menuentry 'Ubuntu' --class ubuntu --id gnulinux-simple {"
echo "    search --no-floppy --fs-uuid --set=root $OLDB"
echo "    linux /boot/vmlinuz-6.8.0-52-generic root=UUID=$OLDR ro quiet splash"
echo "    initrd /boot/initrd.img-6.8.0-52-generic"
echo "}"
echo "submenu 'Advanced options for Ubuntu' --id gnulinux-advanced {"
ent "Ubuntu, with Linux 6.8.0-52-generic" k52 6.8.0-52-generic initrd.img-6.8.0-52-generic
ent "Ubuntu, with Linux 6.8.0-52-generic (recovery mode)" k52r 6.8.0-52-generic initrd.img-6.8.0-52-generic
ent "Ubuntu, with Linux 6.8.0-45-generic" k45 6.8.0-45-generic initrd.img-6.8.0-45-generic
ent "Ubuntu, with Linux 6.8.0-45-generic (recovery mode)" k45r 6.8.0-45-generic initrd.img-6.8.0-45-recovery
echo "}"
} > boot/grub/grub.cfg
cat > etc/fstab <<FS
# /etc/fstab: static file system information (cloned from web-05-old)
# / was on /dev/sda2 during installation
UUID=$OLDR /     ext4  errors=remount-ro 0 1
# /boot was on /dev/sda1 during installation
UUID=$OLDB /boot ext4  defaults 0 2
# swap was on /dev/sda3 during installation
UUID=$OLDS none  swap  sw 0 0
# data disk of the old VM
UUID=$OLDD /data ext4  defaults 0 2
FS
ln -s /usr/lib/systemd/system/multiuser.target etc/systemd/system/default.target
cat > etc/systemd/system/vendor-agent.service <<U
[Unit]
Description=Vendor monitoring agent

[Service]
ExecStart=/usr/local/vendor/agent/run
Restart=no

[Install]
WantedBy=multi-user.target
U
ln -s /etc/systemd/system/vendor-agent.service etc/systemd/system/multi-user.target.wants/vendor-agent.service
printf '#!/bin/sh\nexec sleep 100000\n' > opt/agent/bin/run; chmod 755 opt/agent/bin/run
cd ..
cat > blkid.txt <<B
/dev/sda1: LABEL="boot" UUID="$NEWB" TYPE="ext4" PARTUUID="0f21a7c1-01"
/dev/sda2: LABEL="cloudimg-rootfs" UUID="$NEWR" TYPE="ext4" PARTUUID="0f21a7c1-02"
/dev/sda3: UUID="$NEWS" TYPE="swap" PARTUUID="0f21a7c1-03"
B
echo "$NEWR $NEWB $NEWS $OLDR $OLDB $OLDS $OLDD" > .lm/uuids
( cd sysroot && find boot/vmlinuz* boot/initrd.img* dev/disk opt -type f -o -type l | sort | while read -r f; do echo "$f $(readlink "$f" 2>/dev/null || sha256sum < "$f" | cut -c1-64)"; done ) > .lm/frozen.txt
exit 0
