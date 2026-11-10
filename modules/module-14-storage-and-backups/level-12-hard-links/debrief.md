# Deleted but Still There

## Why it works
A file name is only a directory entry pointing at an inode. `ln` makes more entries for the same inode (hard
links), and the inode, with its data, is freed only when the **link count** reaches 0 and nobody has the file
open. So `rm` of one name freed nothing: the other names kept the data alive.

`find -samefile FILE` (or `find -inum N`) lists every path pointing at the same inode, wherever it is, and
`ls -li` or `stat -c %h` shows the count. A copy made with `cp` is a different inode with its own data, even
if `cmp` says the contents are the same, which is why equal checksums prove nothing about links.

## Common mistakes
- Deleting everything with the same name, size or checksum: separate copies are not links.
- Searching only visible directories: hidden ones (`.cache`) are skipped by `ls *` and by shell globs.
- Using `rm` on `data/big.dat` itself and keeping another name; the task wants that one name to stay.

## Next step
`find / -xdev -links +1 -type f` finds all hard-linked files on a file system, `du` counts a hard-linked file
only once per run, and `rsync -H` or `cp -a` preserve links when copying.
