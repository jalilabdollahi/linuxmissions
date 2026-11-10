#!/bin/bash
grep -rn emergency sysroot/etc/default
sed -i -E 's/ ?systemd\.unit=emergency\.target//; s/ ?emergency//' sysroot/etc/default/grub sysroot/etc/default/grub.d/99-debug.cfg
./update-grub
grep -n '^[[:space:]]*linux' sysroot/boot/grub/grub.cfg
