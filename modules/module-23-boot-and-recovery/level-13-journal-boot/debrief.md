# Which Boot Died?

## Why it works
Every journal entry records the boot it came from in `_BOOT_ID`. A boot that is shut down
by systemd ends with `systemd-shutdown` messages; a boot that hangs or loses power ends
mid-stream. Collecting the IDs that do have the closing message and subtracting them from
all IDs leaves the crashed boot. Because two exports were concatenated, the lines are not
in time order, so the errors had to be sorted by `__REALTIME_TIMESTAMP` after reading
the whole file with `jq -s`.

## Common mistakes
- `select(.PRIORITY <= 3)`: journal JSON stores `PRIORITY` as a string, so nothing matches
  until you apply `tonumber`.
- Taking the boot with the latest timestamps, or the first line of the file, as "the crash".
- `grep -i error`: it picks up routine `PRIORITY 6` lines such as `apport-error-report`.

## Next step
`journalctl --list-boots` and `journalctl -b -1 -p err` do this on a live system, and
`journalctl --file=export.journal` reads a journal file directly. `jq -s` and `group_by(._BOOT_ID)`
summarise all boots in one pass.
