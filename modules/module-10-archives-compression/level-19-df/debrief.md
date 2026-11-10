# Will It Fit

## Why it works
`xz -l --robot` reads the sizes stored in the .xz index, so you get the exact
uncompressed byte count without unpacking anything; `tar -tJf | wc -l` counts
members, and each member (file or directory) costs one inode. On each host
the restore lands on whatever filesystem holds /srv: the `/srv` mount if
there is one, otherwise `/` (a `/srv/backup` mount only covers that subdir).
A target needs both free KiB (`df -P`, Available) and free inodes (`df -i`,
IFree) on that filesystem.

## Common mistakes
- Picking the emptiest disk: one /srv had lots of space but 99% of its
  inodes used. Thousands of small files fail with "No space left on device"
  while `df -h` still shows hundreds of MB free.
- Reading `/srv/backup` as `/srv` on the boxes without a /srv mount.
- Comparing `df -h` / `xz -l` numbers: 58.2M vs 58.3M hides a few hundred KiB
  in either direction. Compare exact KiB.

## Learn next
`df --output=source,avail,iavail,target /srv` prints just the columns you
need for one path on a live system, and `findmnt -T /srv` shows which mount
holds a path. On a real restore also leave headroom: a disk at 100% hurts
everything else on it.
