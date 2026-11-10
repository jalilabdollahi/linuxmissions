# Permission Denied on One Host

## Why it works
`id deploy` prints three parts:
`uid=1003(deploy) gid=1003(deploy) groups=1003(deploy),33(www-data),998(docker)`.
`uid` is the user, `gid` the **primary** group (new files get it), and `groups`
lists every group the process holds, the primary one included. The kernel checks
file access against all of them, so on the host where `gid=33(www-data)` deploy
can write to www-data's directory even though www-data is not a supplementary group.

The pattern `[=,][0-9]+\(www-data\)` matches the group *name* exactly: the closing
parenthesis rules out `www-data-ro`, and `www` never matches.

## Common mistakes
- `grep -L www-data`: `www-data-ro` contains the text too, so that host looks fine.
- Counting only supplementary groups: on the host where `gid=33(www-data)`, www-data is
  deploy's primary group. The kernel checks the primary group too, so that host is fine.
- `echo $UID $GID`: bash sets `$UID`, but `$GID` is not a bash variable and comes out
  empty. `id -u` and `id -g` always work.

## Next step
`id -nG deploy` prints only the group names, one line, easy to `grep -w`.
After `usermod -aG`, a user's running sessions keep the old list until they log in
again; the next level is about exactly that.
