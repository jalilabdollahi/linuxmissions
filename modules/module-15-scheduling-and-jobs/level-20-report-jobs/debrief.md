# Reports Nobody Reads

## Why it works
The original line had three separate defects. `2>&1 > log` first points stderr at the
*current* stdout (cron's pipe, which gets mailed to root) and only then moves stdout to the
file, so the warnings never reach the log; `> log 2>&1` does it in the right order. An
unescaped `%` is a newline to cron, so `date +%F` cut the command in two; `\%F` fixes it.
And cron starts jobs with `PATH=/usr/bin:/bin`: `salesagg` was found in the developer's
shell but not there. A `PATH=` line in the crontab applies to every job below it.

Cron mails whatever a job prints. With everything redirected a good run prints nothing, so
there is no mail. The `|| echo "..."` only runs after a failure, which turns "the job
failed" into the one line that is mailed to `MAILTO`.

## Common mistakes
- Relying on `~` or relative paths: cron runs jobs from the user's home directory.
- Putting `MAILTO=` below the job line: it only affects the lines after it.
- Mailing everything (no redirection): the mailbox fills with reports and the one real failure drowns.

## Next step
`cron-run` is a mock; on a real host `grep CRON /var/log/syslog` (or `journalctl -u cron`) shows
that a job started, but never whether it worked. `chronic` (moreutils) and `healthchecks.io`-style pings are common ways to alert only on failure.
