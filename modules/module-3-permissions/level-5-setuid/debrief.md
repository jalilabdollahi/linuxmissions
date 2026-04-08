# The Audit Trail

## What you practiced
- **SUID (4000)**: Execute as the file's owner, not the calling user — used by `passwd`, `sudo`
- **SGID (2000)**: Execute as the file's group; on directories, new files inherit group
- `find -perm /6000` uses `/` (any of these bits set) vs `-perm 6000` (exact match)

## Security note
SUID/SGID files are a classic privilege escalation vector. Security audits always check for unexpected ones.

## Commands to remember
```bash
find / -perm /4000 2>/dev/null          # all SUID files (system-wide)
find / -perm /6000 2>/dev/null          # SUID or SGID
find / -perm /4000 -user root           # SUID owned by root (highest risk)
ls -la /usr/bin/passwd                  # see -rwsr-xr-x (s = SUID)
stat -c "%a %n" /usr/bin/passwd        # shows 4755
```
