# Since the Window Opened

## Why it works
Every journal entry stores a `PRIORITY` from 0 (emerg) to 7 (debug), set by the program
that logged it. `-p err` keeps 3 and everything more serious. This is not the same as the
word "error" in the text:
- PostgreSQL logs its `ERROR:` level (a failed statement) as syslog **warning**. Only
  FATAL and PANIC become err and crit.
- pgbackrest wrote `ERROR: [082]` to stdout, and the journal records stdout at info.
- sudo logs "3 incorrect password attempts" at **alert**, and sshd's `error:` lines really are err.

`--since 23:40` at 03:10 means 23:40 *today*, which is in the future, so you get
"-- No entries --". A window that crosses midnight needs the full date. systemd
rejects `"yesterday 23:40"`, but accepts `"2026-11-09 23:40"` (and `yesterday` alone
means 00:00 yesterday). `-b` would have cut everything before the reboot.

## Common mistakes
- `journalctl | grep -i error`: it catches info and warning lines that mention errors
  and misses `Failed to start ...` or `Input/output error` lines that say it differently.
- `-p 3` and thinking it means only err. A single level always means "this or worse". For
  exactly one level, use a range: `-p err..err`.

## Next step
`journalctl -p err -b -1` shows the previous boot's errors, which is handy after
a crash. `-o json-pretty` shows the PRIORITY and other fields of an entry, and
`journalctl -p warning..err` selects a band of priorities.
