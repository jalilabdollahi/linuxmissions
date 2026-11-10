# Who Can Write to Builds

## Why it works
In `/etc/exports` the options belong to the host expression directly in front of the parenthesis. With a
space in between, `10.20.0.0/24 (rw)` means two clients: the subnet with default options, and everybody
with `rw`. Joining them puts rw where it was meant to be. Removing `no_root_squash` brings back the default
that maps client root to an unprivileged user. Editing the file changes nothing until `exportfs -r` loads it
into the running table, which is why `exportfs -v` is the real check.

## Common mistakes
- Changing the file and forgetting `exportfs -r`: the old, too-open table stays active.
- Fixing the builds line and leaving `no_root_squash` on another export.
- Adding a second line for the same path instead of correcting the first.

## Next step
`showmount -e server` (from a client) lists what a server exports, and `exportfs -s` prints the table in the
format of exports(5), handy for copying into the file.
