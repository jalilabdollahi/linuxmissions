# The Predictable Temp File

## Why it works
A fixed name such as `/tmp/report.tmp` can be created in advance by anyone, as a symlink to a file the
job's owner can write. The shell's `>` follows the link and overwrites the victim. `mktemp` picks a random
name and creates the file with `O_EXCL` (it fails rather than follow anything that exists) and mode 600, so
there is no window for others. `trap '...' EXIT` runs the cleanup on every way out, including `exit` from
`set -e` after a failed command, which a plain `rm` on the last line never reaches.

## Common mistakes
- `$$` or `$RANDOM` in the name: still guessable, and a symlink can be planted for every PID.
- `tmp=$(mktemp)` without the trap: safe, but the file piles up whenever the script fails.
- `touch "$tmp"; chmod 600 "$tmp"` after the fact: the same race as with a key file.

## Next step
`mktemp -d` creates a private directory for several work files, and `trap ... EXIT INT TERM` also covers
signals. `man 7 symlink` explains how links are followed; `fs.protected_symlinks` is the kernel's partial defence in sticky directories.
