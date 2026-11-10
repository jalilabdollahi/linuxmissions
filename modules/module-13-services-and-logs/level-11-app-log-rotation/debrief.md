# The File Nobody Writes

## Why it works
A process writes to an **open file descriptor**, which points at an inode, not at a name.
`logrotate` with `create` renames `app.log` to `app.log.1` (same inode) and creates a new
empty `app.log` (new inode). The app's fd 3 still points at the old inode, so the app happily
fills `app.log.1`. `ls -l /proc/PID/fd` showed exactly that. With `compress`, the next
rotation would even gzip a file the app is still writing, and deleting it frees no space
while the fd is open.

`postrotate ... endscript` runs after the rename. `systemctl reload app` runs
`ExecReload=` (SIGHUP), and the app closes its fds and reopens the files *by name*, which
now means the new ones. `sharedscripts` runs that script once for the whole
`*.log` pattern instead of once per matched file.

## Common mistakes
- `copytruncate`: no reload needed, but lines written between the copy and the truncate
  are lost, and an app that doesn't open its file with O_APPEND leaves a sparse file
  full of zeros.
- `postrotate` without `sharedscripts` when the pattern matches several files: one
  reload per file. That is harmless here, and a restart storm when the script restarts.
- Testing with plain `logrotate` as non-root: it can't write `/var/lib/logrotate/status`, so use `-s`.

## Next step
`lsof +L1` lists deleted files that are still open, which is the classic reason "df says
full, du says not". Many daemons ship a postrotate already: see
`/etc/logrotate.d/nginx` (`invoke-rc.d nginx rotate`) or rsyslog's `/usr/lib/rsyslog/rsyslog-rotate`.
