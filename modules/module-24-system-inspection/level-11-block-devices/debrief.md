# Pull the Right Disk

## Why it works
The serial identifies a physical drive, the model does not. `lsblk -J`
describes devices as a tree: a disk has partitions as `children`, and a
partition used by LVM has logical volumes below it. The recursive descent
`..` in `jq` visits every depth, so a mount three levels down is found with
the same expression as one directly on a partition. `mountpoints` is always
an array: `[null]` means "not mounted", `[SWAP]` is swap, and a volume can
be mounted in several places.

## Common mistakes
- Matching on `model` and picking the wrong twin.
- Looking only at the disk's direct children and missing the LVM volumes.
- Keeping `null` or `[SWAP]` in the output.
- Using `.mountpoint` (older lsblk, a single string) on this JSON.

## Next step
`lsblk -o NAME,SERIAL,MOUNTPOINTS` shows the same tree on a live box,
`lsblk -s` inverts it (from a volume down to its disks), and `findmnt` and
`blkid` give the filesystem side.
