# Who Filled the Disk

## Why it works
A classic syslog line is `Mon DD HH:MM:SS host tag: message`. The tag is the program
name, usually with `[pid]`. Programs that log through `logger` or a syslog library without
`LOG_PID` show up without it, so both forms have to become the same key.

rsyslog's `$RepeatedMsgReduction on` replaces a run of identical messages with one line:
`message repeated 412 times: [ ... ]`. That line stands for 412 messages. The crash-looping
kubelet logged most of its errors that way, so counting lines put it near the bottom
when it really was near the top.

The time filter is a plain string comparison. That works because every line is from the
same day and the format is fixed-width (`02:00:00` ... `02:59:59`).

## Common mistakes
- Counting the whole file: filebeat flooded the log before 02:00, not during the hour.
- `$3 ~ /^02/` is fine here, but `grep ' 02:'` also matches times inside messages.
- `sort | uniq -c` on `$5`: `orders-api[2231]:` and `orders-api:` end up as two programs.

## Next step
`du -sh /var/log/*` and `journalctl --disk-usage` tell you *where* the space went.
To stop one noisy program, rsyslog can drop it with
`:programname, isequal, "kubelet" stop` in `/etc/rsyslog.d/`, and journald can
rate-limit with `RateLimitIntervalSec=`/`RateLimitBurst=`.
