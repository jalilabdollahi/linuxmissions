# Full Disk, Free Space

## Why it works
Every file needs an inode, and a filesystem has a fixed number of them. Thirty
thousand one-byte session files use almost no space but all the inodes, so
`df -h` looks healthy while `df -i` shows 100 % in IUse%. To find the
directory, `find -printf '%h\n'` prints the containing directory of every file,
and `sort | uniq -c | sort -rn` counts and ranks them. `du` answers a
different question (bytes), which is why the biggest directory by size was not
the culprit.

## Common mistakes
- Trusting `df -h` alone, or `du -sh`, when the problem is the file count.
- Splitting directory names on whitespace: "Delivery Reports" contains a space.
- Counting files recursively: the parent of the culprit then wins; you want files directly inside one directory.

## Next step
`du --inodes -d2 spool | sort -rn | head` ranks by inode count in one step.
Cleaning up with `find DIR -type f -mtime +1 -delete` avoids the "argument
list too long" error that `rm DIR/*` gives with this many files.
