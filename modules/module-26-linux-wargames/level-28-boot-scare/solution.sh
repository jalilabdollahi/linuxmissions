#!/bin/bash
./boot-sim sysroot
cat blkid.txt
new() { grep "^/dev/$1:" blkid.txt | grep -o ' UUID="[^"]*"' | cut -d'"' -f2; }
OLD=($(awk '/^UUID=/{sub("UUID=","",$1);print $1}' sysroot/etc/fstab))
sed -i 's/^set default=.*/set default="1>2"/' sysroot/boot/grub/grub.cfg
sed -i -e "s/${OLD[0]}/$(new sda2)/g" -e "s/${OLD[1]}/$(new sda1)/g" -e "s/${OLD[2]}/$(new sda3)/g" sysroot/boot/grub/grub.cfg sysroot/etc/fstab
sed -i '/^UUID=.*\/data/s/defaults/defaults,nofail/' sysroot/etc/fstab
ln -sfn /usr/lib/systemd/system/multi-user.target sysroot/etc/systemd/system/default.target
sed -i 's|^ExecStart=.*|ExecStart=/opt/agent/bin/run|' sysroot/etc/systemd/system/vendor-agent.service
./boot-sim sysroot
