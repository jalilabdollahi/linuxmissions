# Timed Out Waiting for Device

## Why it works
At boot systemd turns every fstab line into a mount unit and waits for its device. If the
`UUID=` names a disk that is not there (a clone gets new UUIDs), the wait ends after 90
seconds with "Timed out waiting for device" and the machine drops to emergency mode. The
old UUIDs cannot be looked up, so you matched each entry to its new volume by label and
size, and then used either the new UUID or `LABEL=` as the source. The other repairs are
the ones a boot needs too: the type must be the real filesystem (`xfs`, not `ext4`),
an option must exist (`noatme` is not `noatime`) and the mount point must exist. `nofail`
makes a missing removable disk a harmless warning instead of a failed boot.

## Common mistakes
- Deleting the broken lines: the system then boots without `/home` and the data is
  written to the root disk underneath.
- Picking the same-size `home-old` volume instead of the one with the right label.
- Fixing the UUID but leaving the wrong type: the mount then fails later, with a different error.

## Next step
`findmnt --verify` (util-linux) is the real tool that does what ./fstab-lint does, and
`blkid` or `lsblk -f` list the UUIDs you need. `x-systemd.device-timeout=5s` shortens the
wait for an optional disk, and `systemctl daemon-reload` makes systemd re-read fstab.
