# Disk Hog

## What you practiced
- `du -sh *` — disk usage of each item in human-readable form
- `sort -rh` sorts human-readable sizes (K, M, G) in reverse
- `find -printf "%s %p\n"` prints byte size + path — easy to sort numerically

## Commands to remember
```bash
df -h                              # filesystem usage overview
du -sh /var/*                      # size of each item in /var
du -ah / | sort -rh | head -20    # top 20 largest files/dirs
find / -type f -size +100M         # files bigger than 100 MB
ncdu /                             # interactive disk usage (needs ncdu)
```
