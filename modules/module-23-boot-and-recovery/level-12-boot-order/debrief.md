# Firmware Boots the Network

## Why it works
UEFI stores boot entries in NVRAM as `Boot####` variables, and a separate `BootOrder`
list says which to try first. After a firmware update (or a disk swap) that list can put
the network boot ahead of the disk. Each entry's device path names its partition by
`PARTUUID`, so an entry created for a replaced disk still exists but points at nothing.
You matched the paths against `blkid` to find the entry that points at the current EFI
system partition and moved it to the front with `-o`, which sets the list as a whole, so
the other entries have to be named again in their old order.

## Common mistakes
- Picking by name: both entries are called `ubuntu`.
- `efibootmgr -o 0003` alone: the list then contains one entry and the fallbacks are gone.
- Deleting entries (`-B`) when only the order was wrong.

## Next step
`efibootmgr -n 0000` sets a one-time `BootNext` (a single PXE install, say) without
changing the order, and `efibootmgr -c -d /dev/nvme0n1 -p 1 -L ubuntu -l '\EFI\ubuntu\shimx64.efi'`
recreates a lost entry. `grub-install` does that as part of a reinstall.
