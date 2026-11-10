# The Audit Trail

## Why it works
- **SUID (4000)**: the program runs with the *file owner's* rights, not yours.
  That is how `passwd` (owned by root) can write `/etc/shadow`.
- **SGID (2000)**: the program runs with the file's *group*. On a directory it
  means something else: new files inherit the directory's group.

`find -perm -4000` matches files where *at least* that bit is set, whatever the
rest of the mode is, so one command covers 4755, 4750 and 6755 alike. Because
`find` reads modes, not names, it also catches the hidden `.dbus-helper` and
`run backup` with its space, which an `ls | grep s` approach misses.

## Common mistakes
- `-perm 4000` without the dash means "mode is exactly 4000", so it finds nothing.
- Forgetting `-type f`: SGID team directories are normal and would flood the report.
- Trusting names: `suid_audit_notes.txt` is harmless; `libcrypt.so.1` is not.

## Learn next
On a real server: `find / -xdev -type f -perm -4000 -user root 2>/dev/null`.
`-xdev` stays on one filesystem and `2>/dev/null` hides "Permission denied" noise.
Compare the list with your distribution's package files (`dpkg -S path`) to spot
anything that doesn't belong.
