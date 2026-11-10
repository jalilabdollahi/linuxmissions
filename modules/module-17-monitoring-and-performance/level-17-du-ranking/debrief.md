# Where Did the Disk Go

## Why it works
`du` measures the blocks a file really occupies. A sparse VM image can claim
4 GiB in `ls -l` and use a few KiB, so ranking by apparent size
(`--apparent-size`, `ls -l`) puts it first for the wrong reason. And du keeps
track of inodes it has already seen in the same run, so the hard-linked backup
snapshots are counted once, under whichever snapshot du visits first; counting
each snapshot with a separate `du` call triples the figure. A single
`du -d2 var`, filtered to paths exactly two levels deep and sorted numerically,
gives the honest ranking, hidden directories included.

## Common mistakes
- `du -sh var/*/*`: skips dot-directories and cannot be sorted numerically.
- `sort -n` on `-h` output (`1.2G`, `800M`): use `sort -h` or plain `-k` numbers.
- Leaving var and var/lib in the list: `-d2` also prints the parents.

## Next step
`du -x` stays on one filesystem, `ncdu` browses interactively where installed,
and `find -type f -links +1` lists the hard-linked files.
