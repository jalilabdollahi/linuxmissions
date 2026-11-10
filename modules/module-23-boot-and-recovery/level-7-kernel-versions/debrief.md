# Kernel Cleanup in /boot

## Why it works
Every installed kernel owns a `vmlinuz-`, `initrd.img-`, `config-` and `System.map-` file
in `/boot` and a module tree in `/lib/modules/<version>`. The package manager normally
cleans these up (`apt autoremove`); when it cannot, you do it by hand. Two kernels stay:
the newest (so updates and reboots use it) and the running one (its modules are loaded
from `/lib/modules/<uname -r>` while the machine is up, so deleting them breaks hardware
that loads later). `sort -V` compares version numbers part by part, so `6.8.0-9` is
older than `6.8.0-45`, which plain `sort` gets wrong. The `vmlinuz`, `initrd.img`
and `.old` links tell tools which kernel is current and previous.

## Common mistakes
- Treating the last name in an alphabetical list as the newest kernel.
- Deleting the running kernel's modules, because it is not the newest.
- Leaving dangling links: GRUB entries and `update-initramfs` follow them.

## Next step
On a real system use `apt autoremove --purge`, and `dpkg -l 'linux-image-*'` to list what
is installed; it also removes the matching GRUB entries when it runs `update-grub`.
