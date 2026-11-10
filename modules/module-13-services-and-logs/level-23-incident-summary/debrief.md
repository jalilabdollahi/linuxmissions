# 502 at 03:10

## Why it works
The 502s were nginx telling you that api was gone, api was gone because it
could not write its session files, and that was because the disk was full.
The loudest unit (api) was the last domino. The first error in the journal
came from postgresql (`No space left on device`), the kernel and `df` agreed,
and `ls -lS` showed a debug.log of many GiB under another unit's log
directory. The journal named what happened just before it started
writing: a person or a pipeline switched that unit to `LOG_LEVEL=debug`.
Fixing it takes the whole chain: correct the env file, remove the damage,
restart the cause (a running process keeps the old environment), and only
then start the victim again (a unit that hit its start limit stays failed
until `reset-failed`).

## Common mistakes
- Blaming the loudest unit: restarting api alone fails again, or "works"
  until the disk is full again.
- Deleting the wrong big file (here the postgres WAL archive), or deleting a
  log a process still holds open, which frees nothing until it restarts.
- Mixing clocks: the journal export is in UTC epoch time, nginx in local time
  with an offset, and the report asks for UTC.
- Counting `502` with plain `grep`: it also matches sizes and paths; the
  status is field 9.

## Next step
Make the cause harmless for next time: `LogsMaxSec`-style limits, logrotate for
debug logs, and an alert on disk usage before it reaches 100%. A postmortem
should always list first error, root cause, trigger and impact, exactly
like the four fields you just wrote.
