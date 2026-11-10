# Night Shift Handover

## Why it works
Every scheduler stores its jobs in a slightly different shape, and the inventory is mostly
about knowing those shapes. User crontabs have five time fields and then the command: the
owner is the file name. `/etc/crontab` and `/etc/cron.d/*` have a sixth field, the user to run as.
`@reboot`-style lines have one time word. Lines that are comments, blank or `VAR=value` are
configuration, not jobs. `read -r a b c d e rest` is a good fit: it splits the leading fields and
leaves the rest of the line, with its inner spacing, in the last variable. Cron reads only
`/etc/cron.d` files whose names are letters, digits, `_` and `-`, so `.dpkg-old`, `.disabled` and dot-files do
nothing. A systemd timer exists when its file exists but runs only when it is enabled, i.e.
linked in `timers.target.wants`; its command lives in the service it starts (`Unit=` or the same
name). At jobs are in atd's spool; `atq` shows owner and time, `at -c` prints the script and the
command is its last line.

## Common mistakes
- Using `awk '{print $6}'` for the command: it cuts at the first space.
- Listing disabled timers or ignored cron.d files because they look like config.
- Taking the user from the file name for system crontabs, or forgetting the user field when you cut the command.
- Treating `# nightly` at the end of a command as a comment: cron does not strip it; it is part of the command.

## Next step
On a real host: `systemctl list-timers --all`, `crontab -l -u USER` (as root), `atq`, and
`ls /etc/cron.*` cover the same ground. Real inventories also check `/etc/anacrontab` and
the `cron.daily`-style directories.
