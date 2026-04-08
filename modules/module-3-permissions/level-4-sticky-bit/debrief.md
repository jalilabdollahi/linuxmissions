# Shared Space

## What you practiced
The **sticky bit** on a directory means only the file's owner (or root) can delete it, even if the directory is world-writable.

You see it as a lowercase `t` in `ls -la`:
```
drwxrwxrwt  /tmp
```
`T` (capital) means sticky but no execute — unusual.

## Real-world example
`/tmp` always has sticky bit: everyone can write temp files, but only the owner can delete them.

## Commands to remember
```bash
chmod +t /shared             # add sticky bit
chmod 1777 /shared           # rwxrwxrwt (world-writable + sticky)
chmod -t /shared             # remove sticky bit
stat -c "%a" /tmp            # check: should show 1777
ls -ld /tmp                  # drwxrwxrwt
```
