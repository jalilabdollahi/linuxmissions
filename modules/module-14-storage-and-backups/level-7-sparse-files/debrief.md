# The 20 GB Backup

## Why it works
A sparse file has holes: ranges that were never written, which read as zeros but have no disk blocks.
`ls -l` (and `du --apparent-size`) report the length; `du` reports the blocks actually allocated.
A VM image that is "100 GB" can use 3 GB.

Tools only keep holes if they are asked to. `cp` has `--sparse=auto` by default, which copies a sparse
source sparsely but a fully-allocated source in full, even if it is all zeros. `--sparse=always` turns every
zero block into a hole. `tar` does the same in the other direction: `-S` makes it look for holes and store
them as a list instead of as zeros. (GNU tar only scans a file for holes when it looks sparse, which is why a
file made with `dd if=/dev/zero` is archived in full.)

## Common mistakes
- Believing `ls -l` for how much space a file takes.
- Using `gzip` instead of `-S`: zeros compress, but extracting still writes them all out.
- Running `fallocate -d` on the original: it changes the file you wanted to back up as it was.

## Next step
`rsync --sparse` does the same for transfers, and `qemu-img convert` can compact VM disk images.
`filefrag -v FILE` lists the extents of a file, so you can see where its holes are.
