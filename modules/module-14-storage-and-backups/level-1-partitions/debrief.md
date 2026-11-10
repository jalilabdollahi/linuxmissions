# What Is On This Disk?

## Why it works
An MBR disk has room for four partition entries. To get more, one entry becomes an
**extended partition**: a container (type `5`, or `f` for LBA) that holds a chain of
**logical partitions**, always numbered from 5 upwards, whatever the entries before them are.
The container has a partition number of its own, but nothing is stored in it directly, so it
is not a data partition.

`sfdisk -d` prints the exact table in 512-byte sectors, which is easiest to process. A sector
is 512 bytes, so MiB = sectors / 2048. All of this works on a plain image file without root.

## Common mistakes
- Listing the extended container: it looks like a big partition that overlaps the logical ones.
- Dividing by 1000 or 1024 instead of 2048 (sectors are not KiB).
- Taking the type from `fdisk -l` names: `Linux` is type 83, but `Linux swap` and others need the hex id.

## Next step
`sfdisk -J disk.img` prints the same table as JSON for `jq`, and `lsblk -b` or
`partx --show disk.img` show it too.
