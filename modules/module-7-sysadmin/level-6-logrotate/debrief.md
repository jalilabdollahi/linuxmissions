# Log Discipline

## Why it works
logrotate runs once a day from cron or a systemd timer, and it reads every file in
`/etc/logrotate.d/`. Each block pairs file patterns with rules: `daily` + `rotate 14`
keeps two weeks of history, `compress` gzips the old copies (text logs often shrink
by about 90%), and `missingok` avoids an error when, for example, worker.log has not been
created yet.

The important part is `copytruncate`. By default logrotate **renames** the log. A
process that opened the file at startup keeps its file descriptor and continues writing
to the renamed file, so the disk fills up anyway. `copytruncate` copies the content away
and truncates the original in place instead.

## Common mistakes
- Adding a second block for `*.log` and leaving the `app.log` block. logrotate refuses
  a file that is matched twice ("duplicate log entry") and skips it.
- Using `copytruncate` when the app *can* reopen its logs. Lines written between the
  copy and the truncate are lost. Prefer `create` + a `postrotate` script that sends
  the app its reopen signal (e.g. `systemctl reload myapp`).

## Next step
`logrotate -d /etc/logrotate.d/myapp` shows what would happen without changing anything,
and `logrotate -f` forces a rotation now. `delaycompress` leaves the newest rotated copy
uncompressed, which is useful when something still reads yesterday's log.
