# Same Disk, Two Paths

## Why it works
`/proc/mounts` only says "device X is mounted at Y", so a bind mount (`mount --bind
/srv/uploads /var/www/site/uploads`) looks like a second mount of the whole disk.
`/proc/self/mountinfo` adds the **root** field (4th): the directory *inside* the file system
that is visible at the mount point. A normal mount has root `/`; a bind of a subdirectory
shows that subdirectory. The real path on the running system is the place where the device is
mounted normally plus the root field.

The fields before the mount point are fixed, but after the options come zero or more optional
fields (`shared:N`, `master:N`) that end at a lone `-`. That is why a script has to find the
`-` and count from there to reach the file system type and the source.

For the backup, the aliases are excluded and the originals kept, so each file is saved once.
An rsync pattern `/path/` is anchored at the root of the transfer and only matches directories.

## Common mistakes
- Excluding the source directory as well, which removes the data from the backup.
- Reading the file system type as column 9: it is only column 9 when there are no optional fields at all.
- Patterns without the leading slash match any directory with that name anywhere.

## Next step
`findmnt -o TARGET,SOURCE,FSROOT` prints the same information on a live system, and
`rsync -x` (`--one-file-system`) skips other mounts altogether.
