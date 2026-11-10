# Sunday Freeze

## Why it works
To decide whether a line fires in the window you expand it, you don't read it: cron's
rules decide. `7` and `0` are both Sunday. A step in the minute field counts from the
start of the range, so `*/50` is minutes 0 and 50. `@hourly` is `0 * * * *`, every hour.
When a line restricts both the day-of-month and the day-of-week, cron runs it when
**either** matches: `0 3 1 * 0` fires on the 1st and on every Sunday, and `15 3 8-14 * *`
(no weekday restriction) fires on every 8th-14th, including those that are Sundays.
Prefixing with `#FREEZE ` keeps the command in the file, so unfreezing is one `sed`.

## Common mistakes
- Freezing `*/50 4 * * 0` or `0 4 * * 0`: they fire at 04:00, which is after the window.
- Missing the `OR` rule and leaving `0 3 1 * 0` alone because "it's the 1st".
- Freezing lines that only look scary (`@weekly` runs at 00:00 on Sunday, before the window).
- Re-typing lines instead of prefixing them: any changed byte changes the other jobs.

## Next step
`cron-expand` shows fire times for any file. For a real crontab, `crontab -l | cron-expand -`
works the same way. Tools like `systemd-analyze calendar` do it for timer specs.
