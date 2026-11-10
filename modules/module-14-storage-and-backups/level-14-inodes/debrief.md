# No Space, Plenty of Space

## Why it works
A file system has a fixed number of inodes, one per file, chosen when it was created. Forty-odd thousand tiny
session files can use them all while using almost no bytes, so `df` says 40% and writes still fail.
`df -i` shows the inode side. To find the culprit you count files per directory, not bytes per directory:
strip the file name from every path, then `sort | uniq -c | sort -rn`.

`find -mmin +1440 -delete` selects on mtime inside find itself, so there is no huge argument list:
`rm sess_*` fails with "Argument list too long" once the glob expands past the kernel limit.

## Common mistakes
- Trusting `du`: the big log files are a decoy, they use bytes, not inodes.
- Deleting the whole directory or using `-mtime +1`, which means "more than 48 hours" (days are rounded down).
- Forgetting `-name 'sess_*'` and removing the other files in the directory.

## Next step
`find DIR -type f -printf '%h\n' | sort | uniq -c | sort -rn | head` does the counting in one pass, and
`tune2fs -l` / `mke2fs -N` show and set the inode count of an ext file system.
