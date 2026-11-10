# The Backup That Ate the Disk

## Why it works
The I/O scheduler (CFQ-like policies such as BFQ) honours a per-process I/O
class: real-time, best-effort (the default) and idle. A process in the idle
class only gets disk time when nobody else is asking for it, which is exactly
what a backup should do on a busy database host. The change applies to a
running process at once, so nothing has to be restarted. `tar -z` starts
a helper that runs `gzip`, which is the process doing the writing, and a child
does not follow a later change to its parent, so tar and the gzip below it both
had to be changed (`pstree -p` shows the chain).

## Common mistakes
- `ionice` only the `tar` you can see in `ps`, or only its direct children:
  the gzip that writes sits a level further down and keeps its old class.
- `ionice -c3 -P PGID` or `-u USER`: affects everything in the group or of
  the user, including the database.
- Stopping the backup with SIGSTOP/kill: the ticket said it must finish.

## Next step
`ionice -c2 -n7 command` starts a job at the lowest best-effort priority,
and `ionice -c3 tar ...` starts a backup in the idle class from the very
beginning. Together with `nice -n 19` it is the usual way to run maintenance
jobs politely. (The idle class needs a scheduler that supports it; check
`/sys/block/DEV/queue/scheduler`.)
