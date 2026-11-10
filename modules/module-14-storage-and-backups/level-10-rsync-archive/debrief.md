# Migrate the Site

## Why it works
`rsync -a` is shorthand for `-rlptgoD`: recurse, keep symlinks as symlinks, permissions, times, group, owner and
special files. It does **not** include `-H`, so two names for one file become two separate files unless you add it.
Run twice, rsync only transfers what differs, so a second run in dry-run (`-n`) itemized (`-i`) mode is a proof:
an empty list means source and copy match in everything rsync compares.

The **trailing slash** on the source means "the contents of": `www/` copies what is inside `www`, while `www`
copies the directory too and gives you `new-server/www/www`.

## Common mistakes
- `rsync -a www new-server/www`: a nested `www/www`.
- Forgetting `-H`: the data is duplicated and the link between the files is gone.
- `cp -r`: loses modes, times and turns symlinks into copies of their targets (with `-L`) or keeps them
  (default) but drops the times.

## Next step
`--stats` summarises how much was transferred, `-A -X` add ACLs and extended attributes, and `--numeric-ids`
keeps numeric owners when the user names differ between machines (needs root to change owners).
