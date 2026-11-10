# The Backup That Went Nowhere

## Why it works
A directory such as `/mnt/backup` exists whether or not a disk is mounted on it. When the
mount is missing, anything written there goes to the parent file system (here the system
disk), and the backup "succeeds" while the real disk stays empty. `mountpoint -q DIR` asks
the kernel's mount table instead and answers with its exit status (0 mounted, 1 not), so
`if ! mountpoint -q "$TARGET"` is the correct guard. The script exits non-zero, so cron
mails the failure instead of hiding it.

When a disk is finally mounted over a non-empty directory, the old files are hidden, not
deleted, which is why they have to be moved out first.

## Common mistakes
- `[ -d "$TARGET" ]` or `[ -w "$TARGET" ]`: both are true for an unmounted directory.
- `mv mnt/backup/* stray/`: the shell glob skips names starting with a dot.
- Calling `/usr/bin/mountpoint` by full path, which makes the script impossible to test with a stand-in.

## Next step
`findmnt -T PATH` shows which mount PATH belongs to, and `findmnt --target` tells you whether
a path is on the disk you expect. In a mount unit, `ConditionPathIsMountPoint=` does the same check.
