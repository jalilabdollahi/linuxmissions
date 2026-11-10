# Plan the Log Volume

## Why it works
`mke2fs` (also called `mkfs.ext4` when you pass `-t ext4`) writes a file system into whatever
it is pointed at, and a regular file works just as well as a disk. Three of its options matter
for planning a volume:

- `-m` is the percentage of blocks reserved for root. The default is 5%, which on a big data
  volume is a lot of space nobody can use. Root's reserve helps on `/`, not on a log volume.
- `-i` sets the bytes-per-inode ratio. Every file needs an inode, and the number of inodes is
  fixed when the file system is created. Millions of tiny files can run out of inodes while
  most of the space is free.
- `-L` sets the label, which later lets you mount by `LABEL=`.

`dumpe2fs -h` prints the superblock so you can check all of it without mounting.

## Common mistakes
- Creating the file system first and resizing the image afterwards: the file system keeps its small size.
- Passing `-m 0.01`-style guesses instead of the percentage, or confusing `-i` (bytes per inode) with `-N` (inode count).
- Forgetting `-F`: `mke2fs` asks for confirmation on a plain file only if it already contains a file system.

## Next step
`tune2fs -m 1 logs.img` changes the reserve later, and `tune2fs -l` is the same listing as `dumpe2fs -h`.
`resize2fs` grows a file system, but cannot add inodes beyond the block groups it creates.
