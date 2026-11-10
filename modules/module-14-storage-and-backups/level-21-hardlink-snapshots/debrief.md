# Snapshots that Share

## Why it works
A hard link is a second name for the same inode, so identical files in two snapshot directories can occupy the
disk once. `rsync --link-dest=DIR` compares each source file with the one in DIR (size, mtime, mode with `-a`):
if identical it creates a hard link instead of copying; if not, it writes a new file, so the old snapshot keeps
the old version. Files that are gone from the source are simply not created, so deletions appear in day 2 and
day 1 still has them. Each snapshot looks like a full copy, and removing day 1 later frees only the files that
no other snapshot links to.

- A relative `--link-dest` is relative to the destination directory: `../day1` from `snapshots/day2/`.
- The first snapshot must be a real copy: `cp -al site snapshots/day1` links to the live files and follows
  in-place edits.

## Common mistakes
- `--link-dest=snapshots/day1`: resolved as `snapshots/day2/snapshots/day1`, does not exist, silent full copy.
- Taking day1 after the change, or without `-a` (mtimes differ, nothing links).

## Next step
`du -sh snapshots/*` counts a shared file only once per invocation, so the second day looks small; that is how
rsnapshot and Time Machine-style backups work.
