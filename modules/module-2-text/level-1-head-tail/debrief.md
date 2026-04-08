# Log Triage

## What you practiced
- `head -n N` prints the first N lines (default 10)
- `tail -n N` prints the last N lines
- `tail -f` **follows** a file — essential for live log monitoring

## Commands to remember
```bash
head -n 20 file.log              # first 20 lines
tail -n 50 file.log              # last 50 lines
tail -f /var/log/syslog          # follow live
tail -n +100 file.log            # everything FROM line 100 onwards
head -c 1024 file.bin            # first 1024 bytes
```
