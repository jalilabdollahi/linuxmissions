# Files That Vanish

## Why it works
Deleting or renaming a file is a permission on the *directory*, not on the file. In a
folder everybody can write to, everybody can delete everybody else's files. The sticky
bit (`chmod +t`, shown as `t` in `drwxrwxrwt`) changes that: only the file's owner, the
directory's owner or root may remove an entry. `/tmp` has it for the same reason.

`find srv -type d -perm -0002 ! -perm -1000` is the audit query: real directories, writable
by others, without the sticky bit. `-type d` leaves out the symlink (whose own mode is always
`lrwxrwxrwx`) and the world-writable files, for which a sticky bit means nothing.

## Common mistakes
- Dropping `-type d`: the symlink and the files are listed too, and `chmod +t` on a symlink
  changes its target.
- `for d in $(find ...)`: the directory with a space in its name is split in two.
- Running `chmod -R +t srv`: puts the bit on every file and folder, including the ones that
  never needed it.

## Next step
`find / -xdev -type d -perm -0002 ! -perm -1000 2>/dev/null` is the whole-system version
of this audit; a clean host prints nothing (or only mounts that are meant to be shared).
