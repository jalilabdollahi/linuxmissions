# Which Clock?

## Why it works
A timestamp without a zone is only half a fact. The kernel messages were
printed with `--utc`, the application writes local time, and `timedatectl`
tells you which local time that is. `TZ=Zone date -d 'UTC time'` lets GNU
date do the arithmetic, including offsets like +03:30, +05:45 or -03:30, and
the change of date at midnight.

## Common mistakes
- Searching app.log for the UTC clock time: there is a line at that time too,
  just from a different moment.
- Rounding the offset to whole hours: India, Iran, Nepal, Newfoundland and
  South Australia have 30 or 45 minutes in theirs.
- Getting the direction wrong: local = UTC + offset; for a negative offset
  the local clock is behind UTC.

## Next step
Log in UTC, or with the offset (ISO 8601 `2026-11-10T02:17:13+03:30`), and the
problem disappears. `journalctl --utc` and `journalctl -o short-iso` show
journal times either way, and `date -d @EPOCH` converts Unix timestamps.
