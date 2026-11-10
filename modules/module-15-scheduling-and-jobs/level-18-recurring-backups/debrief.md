# The Backup Calendar

## Why it works
Cron has one rule that surprises people: when both the day-of-month and the day-of-week
fields are restricted, a job runs when **either** one matches. So `30 1 2-31 * 1-6` would not
mean "Monday to Saturday, except the 1st"; it would mean "on any of those dates, and also
on every Monday to Saturday". The way out is to keep the time fields simple and test in
the command: `[ "$(date +\%d)" != 01 ] && backup.sh incremental` runs the backup only
when the day of the month is not 01. The `%` has to be escaped as `\%`, because cron
treats an unescaped `%` as the end of the command and feeds the rest to its standard
input. The archive line (`0 3 1 * *`) and the Sunday full backup need no guard.

## Common mistakes
- Writing `\%` as `%`: the job runs `[ "$(date +` and fails with a syntax error every night.
- Relative paths (`./backup.sh`): cron starts in the user's home, not in your directory.
- Guarding with day-of-month ranges (`2-31`) and a weekday range, which triggers the OR rule.

## Next step
`cron-run --days 62` (or any window) plays the calendar without waiting. The same
trick works for any "except" rule: `[ "$(date +\%u)" -le 5 ]` for weekdays only,
or `[ "$(( $(date +\%s) / 86400 \% 14 ))" -eq 0 ]` for "every other week".
