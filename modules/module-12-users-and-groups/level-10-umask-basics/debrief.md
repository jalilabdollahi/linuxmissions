# Reports Nobody Can Edit

## Why it works
A new file is created with mode 666 and a new directory with 777, minus the bits in the
creating process's **umask**. The default 022 takes away group and other write, so files come
out 644 and directories 755: the group can read but not edit. With `umask 002` only "other write"
is removed: 664 and 775. Because the umask is part of the process and is inherited by its
children, setting it once at the top of `publish.sh` covers `mkdir`, the `>` redirections and
`sort` alike, and it works whatever umask the caller (a shell, cron) had. The caller's own umask is
not touched, since the script runs in its own process.

## Common mistakes
- Setting the umask after the `mkdir`: the directories are already created with the old mask.
- `( umask 002 )` on its own line: the subshell exits and the setting goes with it.
- Fixing it with `chmod` at the end: it works once, but hides what the mask is for, and files
  that other tools create later in the same directory are not covered.
- Thinking `umask 002` adds bits: it only removes them from the base mode (a mask of 0 gives 666 and 777).

## Next step
`umask -S` prints the same mask symbolically (u=rwx,g=rwx,o=rx). For directories where new files
must also inherit the group, add the setgid bit with `chmod g+s dir`.
