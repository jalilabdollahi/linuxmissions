# Wrong Owners After Restore

## Why it works
A file stores only numbers: a UID and a GID. The names you see in `ls -l` come from
looking those numbers up in `passwd` and `group` on the machine you are on. So a backup
restored with `--numeric-owner` keeps the old numbers, and if the new machine
has `dave` where the old one had `carol`, `ls` will happily show the wrong person. The fix
goes through the old account files: number -> name on the old server, then `chown` by *name*
on the new one (which looks up the new numbers). Users and groups have their own number
spaces, so each is mapped with its own file, and an owner that is missing on the new host
has to be reported instead of guessed.

## Common mistakes
- Looking up the old UID in the *new* passwd: `1003` is `bob` on app-09, but was `carol`.
- Using the user's name for the group (`alice:alice`): the group of a file is its own thing.
- Unquoted paths: `Q3 report.xlsx` becomes two arguments and `Marta's notes.txt` breaks the quoting.
- `chown user:` (with a colon and nothing after it) changes the group to the user's *login group*.

## Next step
`find / -nouser -o -nogroup` lists files whose numbers no longer match any account, which is the
quickest check after a restore. `rsync --usermap=...` and `tar --owner-map` can do the mapping while restoring.
