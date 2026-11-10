# What Is in the Box?

## Why it works
`blkid -p` skips the cache and probes the device or file directly, so it works on image files without root. For
a whole disk image it finds a partition table (`PTTYPE`), not a file system. The file systems live inside the
partitions, so you read their start sectors from `sfdisk -d`, multiply by 512, and probe at that offset with `-O`.
`-o export` prints stable `KEY=value` lines that are easy to parse; fields the image lacks (no label) are simply
absent.

- A blank image makes blkid exit 2 and print nothing. In a script with `set -e`, or `&&` chains, that stops the loop.
- ext2 and ext4 differ by features (a journal and extents), and blkid reports the right one.
- Swap has a UUID and an optional label like any file system.

## Common mistakes
- Believing the file name or the extension.
- Reporting the disk image as one row with TYPE "dos".
- Probing the partition at offset 0, or using sector numbers where bytes are needed.

## Next step
`blkid -p -S SIZE -O OFFSET` limits the probe to a range, `losetup -P` (root) exposes partitions as devices, and
`lsblk -f` is the friendly view on a real machine.
