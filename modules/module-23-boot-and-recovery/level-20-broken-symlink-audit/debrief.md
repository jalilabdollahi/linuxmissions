# Links That Only Work on the Rescue Host

## Why it works
A symlink stores a path, not a file. An absolute path is resolved from the root of whichever system
looks at it, so a copy of the server's tree mounted somewhere else changes the meaning of every
absolute link: `find -xtype l` and `ls -L` use the rescue system's `/`. To judge what the server
will see, you follow each link yourself with `readlink`, prefix absolute targets with the mount
point, and keep following when the result is a link too (`/bin` is a link to `usr/bin`, an
alternatives entry is a link to a link). A loop never ends, so it is capped. The repair must use paths the
server understands: `/usr/bin/mawk`, not `sysroot/usr/bin/mawk`.

## Common mistakes
- Trusting `find -xtype l`: it misses links that point at host files and flags links that are fine.
- Repairing a link with a target that includes the rescue path: it works here and breaks on boot.
- Repairing `usr/bin/awk` instead of the `etc/alternatives/awk` it points through.

## Next step
`chroot sysroot` (as root) makes all absolute paths resolve against sysroot, which is the
easy way to test; `realpath -m --relative-base=...` and `namei -l PATH` show every step of a path, and
`update-alternatives --list awk` shows which versions are registered.
