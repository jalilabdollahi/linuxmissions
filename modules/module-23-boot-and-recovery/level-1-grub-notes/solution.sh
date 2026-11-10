#!/bin/bash
# set default="1>2": top-level item 1 (the submenu), entry 2 inside it.
grep -n "^set default" sysroot/boot/grub/grub.cfg
grep -n "menuentry\|submenu" sysroot/boot/grub/grub.cfg
awk '/^submenu/ {inside=1; next} inside && /menuentry / {if (n++ == 2) {split($0, a, "\x27"); print a[2]; exit}}' sysroot/boot/grub/grub.cfg > default_entry.txt
grep -F "$(cat default_entry.txt)" sysroot/boot/grub/grub.cfg | head -1
sed 's/^Ubuntu, with Linux //' default_entry.txt > default_kernel.txt
cat default_entry.txt default_kernel.txt
