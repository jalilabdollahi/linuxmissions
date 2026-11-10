# The Box That Sleeps At Night

## Why it works
Cron only runs a job if the machine is up at that minute; a missed run is simply gone.
`last -x` shows when the box was down: a `shutdown` record starts a downtime, the next
`reboot` record ends it. A night counts as missed when 02:00 lies inside such a span. The
two nights the box stayed up have no shutdown record and the job ran. A crash is the odd one:
it leaves no shutdown record, so the span is only visible because the *next* reboot follows a
session that ends in `crash`, and the downtime lasts until that reboot. Here it covered two
02:00 slots. Anacron fixes the root cause: it remembers when each job last ran (in
/var/spool/anacron) and, at boot, runs jobs that are overdue after their delay. One line
`1 10 build-nightly <command>` means "once a day, 10 minutes after anacron starts if it did not run today".

## Common mistakes
- Counting every shutdown, not every 02:00 inside downtime: the crash night has no shutdown line, and a second night after the crash was missed too.
- Keeping the job in both crontab and anacrontab: on days the box is up it runs twice.
- A job id with a slash, a reused id, or a delay of 0: anacron rejects or mishandles them.

## Next step
`anacron -T` tests an anacrontab, `anacron -n` runs due jobs now, ignoring delays. On systemd
machines a timer with `Persistent=true` does the same catch-up job.
