# Default Lockdown

## What you practiced
**umask** = the bits that get *removed* from default permissions:
- Default file permissions: `666` (rw-rw-rw-)
- Default dir permissions: `777` (rwxrwxrwx)
- Applied: `actual = default & ~umask`

| umask | Files | Dirs |
|-------|-------|------|
| 022   | 644   | 755  |
| 027   | 640   | 750  |
| 077   | 600   | 700  |

## Commands to remember
```bash
umask                        # show current umask
umask 027                    # set for current shell session
umask -S                     # show in symbolic form (u=rwx,g=rx,o=)
# Persist in ~/.bashrc or ~/.profile:
echo "umask 027" >> ~/.bashrc
```
