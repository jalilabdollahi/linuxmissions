# Five Schedules

## Why it works
A crontab line fires at every minute where **all five** fields match: minute, hour,
day of month, month and day of week. Each field takes a single value, a range `9-16`,
a list `1,4,7,10`, a step `*/15` (or `9-16/2`), or names like `mon-fri` and `jan`.
The validator expanded each line over a whole year and compared the fire times, so
`*/15` and `0,15,30,45` count as the same answer.

## Common mistakes
- `*/15 9-17 * * 1-5`: ranges include both ends, so this also runs at 17:00, 17:15,
  17:30 and 17:45, after the office has closed. For "until 17:00" the hour range ends at 16.
- `* */2 * * *`: the `*` in the minute field means every minute, so the job runs 60 times
  in each even hour. "On the hour" is minute `0`.
- Restricting both day fields (`15 4 1-7 1,4,7,10 1`). When day-of-month **and**
  day-of-week are both restricted, cron runs on days that match **either** one.

## Next step
Steps work on ranges too: `0 8-18/2 * * *` runs at 08:00, 10:00, ... 18:00.
`@daily`, `@weekly` and `@reboot` are shortcuts for common schedules; see `man 5 crontab`.
