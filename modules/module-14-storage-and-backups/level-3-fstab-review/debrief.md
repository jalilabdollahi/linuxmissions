# Fstab After the Disk Swap

## Why it works
A line in `/etc/fstab` has six fields: **device, mount point, type, options, dump, pass**.
Using `UUID=` for the device makes the file independent of the order the kernel finds disks
in, but the UUID belongs to the *file system*, so a new disk has a new one and every line
must be updated. `blkid` prints it in the `UUID` column.

- `nofail` tells systemd that a missing device must not stop the boot. Without it a
  removable disk that is not plugged in sends the machine to emergency mode.
- The last column is the `fsck` order: `1` only for `/`, `2` for other disks that are
  checked afterwards, `0` for "never" (swap has nothing to check, and XFS has no boot-time fsck).
- Swap has no directory, so its mount point field is the word `none`.

## Common mistakes
- Copying the `PARTUUID` column: it is an ID of the partition entry, not of the file system, so
  `UUID=` with it never matches anything.
- Giving every file system pass 1, so they are all checked at the same time and the root check is not first.
- Rewriting the whole file and losing the comments or the options of a line.

## Next step
`findmnt --verify` (as root, on the real machine) checks an fstab for mistakes before you reboot.
`systemctl daemon-reload` makes systemd re-read fstab. Module 23 deals with a machine that will not boot at all.
