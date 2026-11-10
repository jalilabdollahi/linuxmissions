# Stale Library

## Why it works
When a package replaces a shared library it writes a new file and renames it
over the old one. The old inode lives on as long as a process has it mapped,
and `/proc/PID/maps` marks such a mapping `(deleted)`. A process started
after the upgrade maps the new file at the same path, so it looks fine. Only
`/proc/PID/maps` tells the two apart; the file name never does.

## Common mistakes
- Using `lsof` or `/proc/PID/fd` instead of maps: a process that merely holds
  the old file open as a descriptor is not running old library code, and does
  not need the restart.
- Restarting everything "to be safe". It works, but it is an outage you did
  not need for the services that were already fine.
- Forgetting that the file name is not enough: the PID has to be mapped back
  to its unit (`systemctl show -P MainPID`).

## Next step
This is what `needrestart` and `checkrestart` automate on real servers.
`lsof +L1` lists open files that were deleted, and `ls -l /proc/PID/map_files`
shows each mapping as a link.
