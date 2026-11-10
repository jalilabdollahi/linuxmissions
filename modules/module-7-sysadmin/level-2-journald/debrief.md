# Log Hunt

## Why it works
Every journal entry carries structured fields: the unit that wrote it, a syslog
**priority** (0 emerg … 3 err … 7 debug), and an exact timestamp. `journalctl -u`,
`-p` and `--since` filter on those fields, so you get every real failure, including
"Out of memory" and "Failed to bind", which never contain the word *error*.
Health checks that only print `error_rate=0.02` are left out. `-p err` means
"err **and everything more serious**".

## Common mistakes
- `journalctl | grep error`: misses crit/err lines that say "Failed" or "refused",
  and catches harmless info lines and other units' errors.
- `grep 14:` to get "since 14:00" also matches yesterday's 14:xx entries and IPs or ports.
  Use `--since`/`--until` instead.

## Next step
`journalctl -u myapp -b` limits the output to the current boot, and `-o json-pretty`
shows every field the journal stores for an entry (`_PID`, `PRIORITY`,
`_SYSTEMD_UNIT`, ...), so you can filter on them directly, e.g. `journalctl _PID=2210`.
