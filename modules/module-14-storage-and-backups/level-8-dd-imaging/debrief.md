# Cut Out Partition 2

## Why it works
A partition is just a range of sectors in the disk image. `sfdisk -d` gives the first sector and the
length of each in 512-byte sectors. `dd` copies in blocks of `bs` bytes: `skip=` blocks are skipped on the
input and `count=` blocks are copied. With `bs=512` the numbers from the table can be used unchanged.
`sha256sum -c` then verifies the result against the vendor's file.

## Common mistakes
- `bs=1M skip=<start sector>`: `skip` counts blocks, so this skips that many megabytes (and a partition
  does not have to start on a megabyte).
- Forgetting `count`, so dd copies everything after the start of the partition, including partition 3.
- Using a big `bs` (for speed) together with sector numbers from the table. If you want a big block size,
  use `iflag=skip_bytes,count_bytes` and give skip and count in bytes (sectors times 512).

## Next step
`dd status=progress` shows progress, `losetup -P` (root) exposes the partitions of an image as devices, and
`partx --show disk.img` or `fdisk -l` lists them. `ddrescue` is the tool for failing disks.
