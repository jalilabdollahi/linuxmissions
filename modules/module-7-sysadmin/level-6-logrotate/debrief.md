# Log Discipline

## What you practiced
Logrotate rules combine a file pattern with a block of lifecycle settings. A small config can save a lot of disk space over time.

## Commands to remember
```bash
/var/log/myapp/*.log {
  daily
  rotate 7
  compress
}
```
