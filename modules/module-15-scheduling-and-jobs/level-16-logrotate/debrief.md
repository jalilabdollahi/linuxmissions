# The Log That Won't Let Go

## Why it works
A process writes to an open file, not to a name. Normal rotation renames `app.log` to
`app.log.1` and creates a new `app.log`; the app, still holding the old file, keeps
writing into `app.log.1` while the fresh `app.log` stays empty. `copytruncate` avoids that:
logrotate copies the content to `app.log.1` and truncates the original in place, so the
app's open file is still the one named `app.log`. (A few lines written between the copy and
the truncate can be lost, which is the price when the app cannot be told to reopen its log.)
`rotate 5` keeps five old logs, `compress` gzips them and `delaycompress` leaves the newest
uncompressed, which also helps tools that still read it. `-s` points at a state file, where
logrotate remembers the last rotation of each log; the system default is not writable
without root.

## Common mistakes
- Forgetting `copytruncate`: the log looks rotated but `app.log` is empty and the disk keeps filling.
- Using `-f` before `-d`: always look at the dry run first, a typo in the path rotates nothing silently.
- Writing a relative path or an unwritable state file location and getting "error: ... failed to open".

## Next step
Apps that can reopen their log on a signal are better served by `create` plus
`postrotate ... kill -USR1 ... endscript`: nothing is lost. `size 100M`, `daily`,
`maxage 30` and `dateext` control when and how files are named.
