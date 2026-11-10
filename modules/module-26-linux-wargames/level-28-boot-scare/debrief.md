## What you did

You treated the boot as a pipeline and fixed one stage at a time. GRUB's `default="1>1"` selected a recovery entry of the newest kernel, whose initrd file was missing; the working choice was `1>2` (submenu 1, third entry), the 6.8.0-45 kernel whose initrd contains the driver for the cloned root disk, while its recovery sibling uses an initrd built for the old VM. The clone changed every filesystem UUID, so the `search ... --set=root` and `root=UUID=` lines and `/etc/fstab` needed the new ones from `blkid`, and the vanished `/data` disk needed `nofail` so it would not drop boot into emergency mode. Finally `default.target` was a typo and a vendor unit pointed at a moved binary.

## Common mistakes

- Counting the submenu's entries as top-level entries (`default="2"`), or forgetting that numbering starts at 0.
- Replacing UUIDs in only one of GRUB and fstab.
- Deleting the `/data` line and losing the information, or deleting menu entries instead of choosing the right one.

## Next

On a real system these edits are made in `/etc/default/grub` and regenerated with `update-grub`, `update-initramfs -u -k all` rebuilds initrds for the new hardware, and `blkid`, `lsblk -f` and `findmnt --verify` check identifiers and fstab before a reboot.
