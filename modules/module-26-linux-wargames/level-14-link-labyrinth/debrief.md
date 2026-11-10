# Link Labyrinth

## Why it works
A symbolic link stores a path, resolved at access time: a relative target is
resolved from the directory *containing the link*. Renaming a folder
therefore breaks every link that spelled the old name (`current`, `bin/app`),
two links that point at each other loop ("Too many levels of symbolic
links"), and an absolute target such as `/srv/.../logs` keeps pointing at the old
machine when the tree is copied. A hard link is something else entirely: a
second name for the same inode. `config/active.conf` was a hard link to the
old release's file, so it "worked" but never followed edits to the new one (and
`sed -i` or an editor that writes a new file would have cut it loose even from
that), and writing through it silently changed the old release. Replacing each by a
relative symlink fixes all of it, and `cp -a` into another directory is the
test that proves it.

## Common mistakes
- Fixing with absolute paths: it works here and breaks on the new server.
- `ln -sf` on a link to a directory without `-n`: creates a link inside the target.
- Editing through the hard link to "fix" the config: the old release changes.

## Next step
`ln -sr` builds a correct relative link from where you stand;
`find -L . -type l` (broken links) and `symlinks -r` (the `symlinks` tool)
audit a whole tree; `stat -c '%h %i'` shows link count and inode.
