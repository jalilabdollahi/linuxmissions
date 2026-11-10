# Grandfather, Father, Son

## Why it works
A retention policy is a set of rules, and a backup survives if any rule claims it. The script gives each name
a number (days since the epoch, via `date -u -d ... +%s`), so "within 6 days", "28 days of weeks" and "newest of
its week" are plain integer comparisons that work across month ends, leap days and New Year. Weeks are found
from the last Sunday on or before TODAY; the newest candidate per week is kept, which is the Sunday backup when
it exists and an earlier one when it does not. The monthly window starts at the 1st of the month eleven months
back, computed by `date`, not by subtracting 365 days.

- The name is validated twice: a regex for the shape and `date -d` round-trip for a real date (2026-02-30 fails).
  A file that is not a backup is never part of the delete set: this is also why the `db-latest` symlink survives.
- Dry run by default: the destructive branch is the one that needs an explicit flag.
- `TODAY` from the environment makes the policy testable for any day.

## Common mistakes
- Keeping only Sundays for the weekly rule: a missing Sunday loses the whole week.
- Using `ls | sort | tail -n 7` instead of dates: one day without a backup shifts everything.
- Doing month arithmetic with 30-day months, or with the year number alone.

## Next step
Add a safety net (refuse to delete more than N files, or when the newest backup is older than a day), and run the
script from cron in dry-run mode first, mailing the "would delete" list.
