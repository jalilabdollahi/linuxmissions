# Four Clocks, One Timeline

## Why it works
A timeline is only as good as its clock. Each source got converted once to
the same representation, UTC in fixed-width ISO 8601, and from then on plain
string comparison does the window and the sort. GNU `date -u -f -` converts a
whole column in one process, as long as each line is a format date can read:
the syslog stamp needed its year and zone added, and the nginx stamp needed
its slashes and first colon replaced.

The journal export and syslog overlap because rsyslog reads the journal.
Matching on time and text (`grep -vxF -f`) removes exactly the copies and
keeps what only syslog has: the kernel lines, cron, sshd.

`sort -s -k1,1` sorts on the time alone and is stable: lines with equal keys
keep the order of the input, here journal, syslog, nginx, app.

## Common mistakes
- Plain `sort`: ties are then sorted by the rest of the line, so "app"
  comes before "journal".
- Rounding fractions instead of cutting them: `.987` is still the same second.
- Converting syslog with the host's zone (UTC in the container) instead of
  the server's +03:30.
- Removing duplicates with `sort -u`: the source column differs, so nothing
  is removed, and identical messages from one source would be lost.

## Next step
Log in UTC with an offset everywhere (`journalctl -o short-iso`, nginx
`$time_iso8601`, rsyslog's `RSYSLOG_FileFormat` with RFC 3339 stamps) and this
work goes away. For bigger incidents, `lnav` merges log files by time.
