# Noisy Logs

## Why it works
The app was configured for `warn` in `app.env`, but it reads every file in
`app.env.d/` afterwards and the last one wins; `zz-debug.env`, a leftover
from a debugging session, sorts last. Removing it and sending SIGHUP made
the same process reload its settings without dropping sessions. Emptying the
log in place with `truncate` frees the space while the process keeps a valid
file descriptor, whereas `rm app.log` frees nothing, because the process still
holds the deleted inode open (`ls -l /proc/PID/fd` shows it as "(deleted)").
Finally the rotation config had a typo, pointed at a log path that does not
exist, and would have renamed a file the app keeps writing to; `copytruncate`
(or a HUP in `postrotate`) solves that.

## Common mistakes
- `rm app.log`: the disk stays full and the new log is empty.
- Restarting the app: debug stops, but sessions drop and the file stays.
- Fixing the typo only: `missingok` hides that the path was wrong.

## Next step
`lsof +L1` lists files that are deleted but still open, the classic "df says
full, du says empty" culprit. `man logrotate` also covers `maxsize` and `su`.
