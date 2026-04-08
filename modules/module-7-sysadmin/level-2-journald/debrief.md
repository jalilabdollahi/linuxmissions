# Log Hunt

## What you practiced
`journalctl` becomes much more useful when you bound it by time and then narrow further with a pattern search.

## Commands to remember
```bash
journalctl --since "1 hour ago"
journalctl -u myapp.service
journalctl --since today | grep error
```
